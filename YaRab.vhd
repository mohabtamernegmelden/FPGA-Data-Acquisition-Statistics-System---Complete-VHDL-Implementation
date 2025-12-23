-- keypad_analyses.vhd
-- Target: EP4CE6E22C8N FPGA (CoreEP4CE6 / OpenEP4CE6 style)
-- Full system: Keypad input -> Store in RAM -> Compute statistics -> Display on 7-seg
-- Assumes: 50MHz clock, active-high reset, common-cathode 7-segment display
-- Keypad: 4x4 matrix with standard layout
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity YaRab is
  port (
    clk    : in  std_logic;                       -- 50 MHz oscillator
    reset  : in  std_logic;                       -- Active-high reset (pushbutton)
    rows   : in  std_logic_vector(3 downto 0);    -- Keypad rows (active-low when pressed)
    cols   : out std_logic_vector(3 downto 0);    -- Keypad columns (active-low scanning)
    seg    : out std_logic_vector(6 downto 0);    -- 7-seg segments (a..g, ACTIVE-LOW for common cathode)
    an     : out std_logic_vector(3 downto 0)     -- Digit enables (ACTIVE-LOW for common cathode)
  );
end entity;

architecture rtl of YaRab is

  -- RAM: 32 x 16-bit BCD (4 digits each 4 bits)
  type ram_type is array (0 to 31) of std_logic_vector(15 downto 0);
  signal ram : ram_type;
  signal ram_dout : std_logic_vector(15 downto 0);

  signal display_bcd : std_logic_vector(15 downto 0);

  -- RAM initialization attribute for Block RAM inference
  --attribute ram_init_file : string;
  --attribute ram_init_file of ram : signal is "";  -- Empty = all zeros
  
  signal ram_addr      : integer range 0 to 31 := 0;
  signal number_buffer : std_logic_vector(15 downto 0) := (others => '0');
  signal digit_count   : integer range 0 to 4 := 0;
  signal ram_read_addr : integer range 0 to 31 := 0;

  -- Keypad scanning
  signal col_index : integer range 0 to 3 := 0;
  signal cols_reg  : std_logic_vector(3 downto 0) := (others => '1');
  signal key_code  : std_logic_vector(3 downto 0) := (others => '0');
  signal key_valid_raw : std_logic := '0';
  signal key_valid_stable : std_logic := '0';
  signal key_last_code : std_logic_vector(3 downto 0) := (others => '0');
  signal div17_prev : std_logic := '0';

  -- Display
  type disp_array is array (0 to 3) of std_logic_vector(3 downto 0);
  signal digits : disp_array := (others => (others => '0'));

  -- Clock divider (24-bit for 50MHz -> various slower clocks)
  signal clk_div : unsigned(23 downto 0) := (others => '0');
  signal scan_cnt : integer range 0 to 3 := 0;

  -- Statistics - use std_logic_vector for proper width control
  signal min_val   : unsigned(13 downto 0) := (others => '1');  -- Up to 9999 (14 bits)
  signal max_val   : unsigned(13 downto 0) := (others => '0');
  signal sum_val   : unsigned(27 downto 0) := (others => '0');  -- 32*9999 = ~320k (19 bits), but 28 bits for safety
  signal count_val : unsigned(4 downto 0) := (others => '0');   -- Up to 32 (5 bits)

  -- Display mode: 00=MIN, 01=MAX, 10=AVG, 11=COUNT
  signal mode : std_logic_vector(1 downto 0) := "00";
  signal result_val : unsigned(13 downto 0) := (others => '0');  -- Synchronized version

  -- Key press detection
  signal key_prev_stable : std_logic := '0';
  signal press_event     : std_logic := '0';

  -- Debouncing
  signal stable_ctr : integer range 0 to 15 := 0;
  constant STABLE_THRESHOLD : integer := 4;

  -- Display timing
  signal display_refresh_tick : std_logic := '0';
  signal refresh_counter : unsigned(15 downto 0) := (others => '0');  -- 50MHz/65536 = 763Hz

  -- Display management signals
  signal display_mode_reg : std_logic_vector(1 downto 0) := "00";
  signal showing_input    : std_logic := '1';  -- 1=show input, 0=show stats
  signal input_timeout    : unsigned(19 downto 0) := (others => '0');
  constant INPUT_TIMEOUT_VAL : unsigned(19 downto 0) := to_unsigned(1000000, 20);  -- ~20ms at 50MHz

  -- Intermediate signals for proper pipelining
  signal result_val_comb : unsigned(13 downto 0);
  signal result_val_reg  : unsigned(13 downto 0) := (others => '0');

  -- Key codes (matches standard 4x4 keypad mapping)
  constant KEY_1  : integer := 3;
  constant KEY_2  : integer := 2;
  constant KEY_3  : integer := 1;
  constant KEY_A  : integer := 0;
  

  constant KEY_4  : integer := 7;
  constant KEY_5  : integer := 6;
  constant KEY_6  : integer := 5;
  constant KEY_B  : integer := 4;

  constant KEY_7  : integer := 11;
  constant KEY_8  : integer := 10;
  constant KEY_9  : integer := 9;
  constant KEY_C  : integer := 8;

  constant KEY_STAR : integer := 15;
  constant KEY_0    : integer := 14;
  constant KEY_HASH : integer := 13;
  constant KEY_D    : integer := 12;

  -- BCD to unsigned conversion
  function bcd_to_unsigned(bcd : std_logic_vector(15 downto 0)) return unsigned is
    variable result : unsigned(13 downto 0);
    variable th, h, t, u : integer;
  begin
    th := to_integer(unsigned(bcd(15 downto 12)));
    h  := to_integer(unsigned(bcd(11 downto 8)));
    t  := to_integer(unsigned(bcd(7 downto 4)));
    u  := to_integer(unsigned(bcd(3 downto 0)));
    result := to_unsigned(th*1000 + h*100 + t*10 + u, 14);
    return result;
  end function;

  -- Unsigned to BCD conversion
  function unsigned_to_bcd(n : unsigned(13 downto 0)) return std_logic_vector is
    variable temp : integer;
    variable bcd : std_logic_vector(15 downto 0) := (others => '0');
    variable d : integer;
  begin
    temp := to_integer(n);
    if temp > 9999 then
      temp := 9999;
    end if;
    
    d := temp mod 10;
    bcd(3 downto 0) := std_logic_vector(to_unsigned(d, 4));
    temp := temp / 10;
    
    d := temp mod 10;
    bcd(7 downto 4) := std_logic_vector(to_unsigned(d, 4));
    temp := temp / 10;
    
    d := temp mod 10;
    bcd(11 downto 8) := std_logic_vector(to_unsigned(d, 4));
    temp := temp / 10;
    
    d := temp mod 10;
    bcd(15 downto 12) := std_logic_vector(to_unsigned(d, 4));
    
    return bcd;
  end function;

  -- Seven segment decoder
  function seven_seg(d : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable seg_out : std_logic_vector(6 downto 0);
  begin
    case to_integer(unsigned(d)) is
      when 0 => seg_out := "1000000"; 
      when 1 => seg_out := "1111001"; 
      when 2 => seg_out := "0100100"; 
      when 3 => seg_out := "0110000"; 
      when 4 => seg_out := "0011001"; 
      when 5 => seg_out := "0010010"; 
      when 6 => seg_out := "0000010"; 
      when 7 => seg_out := "1111000"; 
      when 8 => seg_out := "0000000"; 
      when 9 => seg_out := "0010000"; 
      when others => seg_out := "1111111"; 
    end case;
    return seg_out;
  end function;

begin

  ----------------------------------------------------------------------------
  -- CLOCK DIVIDER PROCESS
  ----------------------------------------------------------------------------
  clk_div_proc: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        clk_div <= (others => '0');
        refresh_counter <= (others => '0');
        display_refresh_tick <= '0';
      else
        clk_div <= clk_div + 1;
        
        -- Display refresh: ~763Hz refresh rate, ~190Hz per digit
        refresh_counter <= refresh_counter + 1;
        if refresh_counter = 0 then
          display_refresh_tick <= '1';
        else
          display_refresh_tick <= '0';
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- KEYPAD SCANNING PROCESS
  ----------------------------------------------------------------------------
  keypad_scan_proc: process(clk)
    variable row_index : integer range 0 to 3;
    variable any_low   : boolean;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        col_index     <= 0;
        cols_reg      <= (others => '1');
        key_valid_raw <= '0';
        key_code      <= (others => '0');
        div17_prev    <= '0';
      else
        cols_reg <= (others => '1');
        cols_reg(col_index) <= '0';

        any_low   := false;
        row_index := 0;

        for i in 0 to 3 loop
          if rows(i) = '0' then
            any_low   := true;
            row_index := i;
            exit;
          end if;
        end loop;

        if any_low then
          key_valid_raw <= '1';
          key_code <= std_logic_vector(to_unsigned(col_index*4 + row_index, 4));
        else
          key_valid_raw <= '0';
        end if;

        if clk_div(17) = '1' and div17_prev = '0' then
          if col_index = 3 then
            col_index <= 0;
          else
            col_index <= col_index + 1;
          end if;
        end if;

        div17_prev <= clk_div(17);
      end if;
    end if;
  end process;

  cols <= cols_reg;

  ----------------------------------------------------------------------------
  -- KEY DEBOUNCING - FIXED
  ----------------------------------------------------------------------------
  debounce_proc: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            stable_ctr       <= 0;
            key_valid_stable <= '0';
            key_last_code    <= (others => '0');
        else
            if key_valid_raw = '1' then
                -- If same key as last cycle, increment stable counter
                if key_last_code = key_code then
                    if stable_ctr < STABLE_THRESHOLD then
                        stable_ctr <= stable_ctr + 1;
                    end if;
                else
                    key_last_code <= key_code;
                    stable_ctr <= 1;
                end if;
            else
                stable_ctr <= 0;  -- no key pressed
                key_valid_stable <= '0';
            end if;

            -- Signal stable key press
            if stable_ctr >= STABLE_THRESHOLD then
                key_valid_stable <= '1';
            else
                key_valid_stable <= '0';
            end if;
        end if;
    end if;
end process;


  ----------------------------------------------------------------------------
  -- KEY PRESS EVENT DETECTION
  ----------------------------------------------------------------------------
  press_event_proc: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        key_prev_stable <= '0';
        press_event <= '0';
      else
        press_event <= '0';
        if key_valid_stable = '1' and key_prev_stable = '0' then
          press_event <= '1';
        end if;
        key_prev_stable <= key_valid_stable;
      end if;
    end if;
  end process;

----------------------------------------------------------------------------
-- RAM READ PROCESS
----------------------------------------------------------------------------
  ram_read_proc : process(clk)
  begin
   if rising_edge(clk) then
      ram_dout <= ram(ram_read_addr);
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- MAIN CONTROL: Number entry, storage, statistics update
  ----------------------------------------------------------------------------
  main_proc: process(clk)
    variable int_val_unsigned : unsigned(13 downto 0);
    variable next_ram_addr : integer range 0 to 31;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        number_buffer <= (others => '0');
        digit_count <= 0;
        ram_addr <= 0;
        ram_read_addr <= 0;  -- FIXED: Initialize ram_read_addr
        min_val <= (others => '1');
        max_val <= (others => '0');
        sum_val <= (others => '0');
        count_val <= (others => '0');
        mode <= "00";
      else
        if press_event = '1' then
          case to_integer(unsigned(key_last_code)) is
            when KEY_1 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0001";
                digit_count <= digit_count + 1;
              end if;
            when KEY_2 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0010";
                digit_count <= digit_count + 1;
              end if;
            when KEY_3 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0011";
                digit_count <= digit_count + 1;
              end if;
            when KEY_4 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0100";
                digit_count <= digit_count + 1;
              end if;
            when KEY_5 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0101";
                digit_count <= digit_count + 1;
              end if;
            when KEY_6 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0110";
                digit_count <= digit_count + 1;
              end if;
            when KEY_7 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0111";
                digit_count <= digit_count + 1;
              end if;
            when KEY_8 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "1000";
                digit_count <= digit_count + 1;
              end if;
            when KEY_9 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "1001";
                digit_count <= digit_count + 1;
              end if;
            when KEY_0 =>
              if digit_count < 4 then
                number_buffer <= number_buffer(11 downto 0) & "0000";
                digit_count <= digit_count + 1;
              end if;

            when KEY_HASH =>  -- ENTER/SAVE
				  if digit_count > 0 then
					 int_val_unsigned := bcd_to_unsigned(number_buffer);
					 
					 -- Calculate next RAM address using variable
					 if ram_addr = 31 then
						next_ram_addr := 0;
					 else
						next_ram_addr := ram_addr + 1;
					 end if;
					 
					 -- Store in RAM at current address
					 ram(ram_addr) <= number_buffer;
					 
					 -- Update both addresses to the SAME new value
					 ram_addr <= next_ram_addr;
					 ram_read_addr <= next_ram_addr;
					 
					 -- Update statistics
					-- if count_val = 0 then
					--	min_val <= int_val_unsigned;
					--	max_val <= int_val_unsigned;
					-- else
					--	if int_val_unsigned < min_val then
					--	  min_val <= int_val_unsigned;
					--	end if;
					--	if int_val_unsigned > max_val then
					--	  max_val <= int_val_unsigned;
					--	end if;
					-- end if;

					 -- Add with saturation
				--	 if (sum_val + resize(int_val_unsigned, 28)) < sum_val then
				--		sum_val <= (others => '1');
					-- else
				--		sum_val <= sum_val + resize(int_val_unsigned, 28);
				--	 end if;

					 -- Increment count with saturation at 32
			--		 if count_val < 31 then
			--			count_val <= count_val + 1;
				--	 end if;

					-- number_buffer <= (others => '0');
				--	 digit_count <= 0;
				 -- end if;

                -- Update statistics
                if count_val = 0 then
                  min_val <= int_val_unsigned;
                  max_val <= int_val_unsigned;
                else
                  if int_val_unsigned < min_val then
                    min_val <= int_val_unsigned;
                  end if;
                  if int_val_unsigned > max_val then
                    max_val <= int_val_unsigned;
                  end if;
                end if;

                -- Add with saturation
                if (sum_val + resize(int_val_unsigned, 28)) < sum_val then
                  sum_val <= (others => '1');
                else
                  sum_val <= sum_val + resize(int_val_unsigned, 28);
                end if;

                -- Increment count with saturation at 32
                if count_val < 31 then
                  count_val <= count_val + 1;
                end if;

                number_buffer <= (others => '0');
                digit_count <= 0;
              end if;

            when KEY_STAR =>  -- BACKSPACE
              if digit_count > 0 then
                number_buffer <= "0000" & number_buffer(15 downto 4);
                digit_count <= digit_count - 1;
              end if;

            when KEY_A => mode <= "00";
            when KEY_B => mode <= "01";
            when KEY_C => mode <= "10";
            when KEY_D => mode <= "11";

            when others =>
              null;
          end case;
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- DISPLAY MODE CONTROL - OPTIMIZED
  ----------------------------------------------------------------------------
  display_mode_control: process(clk)
    variable key_int : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        showing_input <= '1';
        input_timeout <= (others => '0');
        display_mode_reg <= "00";
      else
        -- Convert once for efficiency
        key_int := to_integer(unsigned(key_last_code));
        
        -- Default: show input
        --showing_input <= '1';
        
        -- Reset timeout on any key press
        -- Reset timeout on any key press
			if press_event = '1' then
			  input_timeout <= (others => '0');

			  -- Mode selection keys switch to stats immediately
			  if key_int = KEY_HASH or
				  key_int = KEY_A or
				  key_int = KEY_B or
				  key_int = KEY_C or
				  key_int = KEY_D then
				 showing_input    <= '0';
				 display_mode_reg <= mode;
			  end if;

			elsif showing_input = '1' then
			  -- Increment timeout counter
			  if input_timeout < INPUT_TIMEOUT_VAL then
				 input_timeout <= input_timeout + 1;
			  else
				 -- Timeout reached, switch to stats display
				 showing_input    <= '0';
				 display_mode_reg <= mode;
			  end if;
			end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- STATISTICS COMPUTATION (Combinational)
  ----------------------------------------------------------------------------
  compute_result_proc: process(display_mode_reg, min_val, max_val, sum_val, count_val)
    variable avg_temp : unsigned(27 downto 0);
  begin
    case display_mode_reg is
      when "00" =>  -- MIN
        if count_val = 0 then
          result_val_comb <= (others => '0');
        else
          result_val_comb <= min_val;
        end if;
      when "01" =>  -- MAX
        if count_val = 0 then
          result_val_comb <= (others => '0');
        else
          result_val_comb <= max_val;
        end if;
     -- when "10" =>  -- AVG
     --   if count_val = 0 then
    --      result_val_comb <= (others => '0');
    --    else
          -- FIXED: Prevent division by zero
        --  if count_val > 0 then
          --  avg_temp := sum_val / resize(count_val, 28);
           -- if avg_temp > 9999 then
          --    result_val_comb <= to_unsigned(9999, 14);
           -- else
        --      result_val_comb <= avg_temp(13 downto 0);
         --   end if;
      --    else
       --     result_val_comb <= (others => '0');
         -- end if;
        --end if;
		  when "10" =>  -- AVG
			  if count_val = 0 then
				 result_val_comb <= (others => '0');
			  else
				 -- Convert to integer for safe division
				 avg_temp := to_unsigned(
									to_integer(sum_val) / to_integer(count_val),28);
				 if avg_temp > 9999 then
					result_val_comb <= to_unsigned(9999, 14);
				 else
					result_val_comb <= avg_temp(13 downto 0);
				 end if;
			  end if;
      when "11" =>  -- COUNT
        result_val_comb <= resize(count_val, 14);
      when others =>
        result_val_comb <= (others => '0');
    end case;
  end process;

  
  
  ----------------------------------------------------------------------------
  -- مشكلة الشاشة محمد ابراهيم
  ----------------------------------------------------------------------------
  display_latch_proc : process(clk)
begin
  if rising_edge(clk) then
     if reset = '1' then
        display_bcd <= (others => '0');
     else
        if showing_input = '1' then
          display_bcd <= number_buffer;
        else
          display_bcd <= unsigned_to_bcd(result_val);
        end if;
     end if;
  end if;
end process;


  ----------------------------------------------------------------------------
  -- REGISTER THE RESULT FOR SYNCHRONOUS READING
  ----------------------------------------------------------------------------
  result_reg_proc: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        result_val_reg <= (others => '0');
      else
        result_val_reg <= result_val_comb;
      end if;
    end if;
  end process;

  result_val <= result_val_reg;

  ----------------------------------------------------------------------------
  -- DISPLAY SELECTION MUX - FIXED to show RAM contents in AVG mode
  ----------------------------------------------------------------------------
--display_selection_proc: process(showing_input, number_buffer, result_val)
  --  variable selected_bcd : std_logic_vector(15 downto 0);
--begin
   -- if showing_input = '1' then
   --     selected_bcd := number_buffer;           -- show number being typed
   -- else
   --     selected_bcd := unsigned_to_bcd(result_val); -- show statistics: min/max/avg/count
  --  end if;

    -- Split into 4 digits for display
-- Split latched display value into digits
digits(0) <= display_bcd(15 downto 12);  -- Thousands
digits(1) <= display_bcd(11 downto 8);   -- Hundreds
digits(2) <= display_bcd(7 downto 4);    -- Tens
digits(3) <= display_bcd(3 downto 0);    -- Units

--end process;


  ----------------------------------------------------------------------------
  -- 7-SEGMENT DISPLAY MULTIPLEXING
  ----------------------------------------------------------------------------
seg_mux_proc: process(clk)
  variable seg_next : std_logic_vector(6 downto 0);
begin
  if rising_edge(clk) then
    if reset = '1' then
      scan_cnt <= 0;
      an  <= (others => '1');   -- all digits off
      seg <= (others => '1');   -- all segments off
    else
      -- Advance scan counter on refresh tick
      if display_refresh_tick = '1' then
        if scan_cnt = 3 then
          scan_cnt <= 0;
        else
          scan_cnt <= scan_cnt + 1;
        end if;
      end if;

      -- FIX: use digits, not undefined signal
      seg_next := seven_seg(digits(scan_cnt));
      seg <= seg_next;

      -- Enable ONE digit (active-low)
      case scan_cnt is
        when 0 => an <= "1110";
        when 1 => an <= "1101";
        when 2 => an <= "1011";
        when 3 => an <= "0111";
        when others => an <= "1111";
      end case;
    end if;
  end if;
end process;

--Debugging
-- Add debug to check digits values
debug_proc: process(clk)
begin
    if rising_edge(clk) then
        if display_refresh_tick = '1' then
            -- Print or check digits values
            report "Digits: " & 
                   integer'image(to_integer(unsigned(digits(0)))) & " " &
                   integer'image(to_integer(unsigned(digits(1)))) & " " &
                   integer'image(to_integer(unsigned(digits(2)))) & " " &
                   integer'image(to_integer(unsigned(digits(3))));
        end if;
    end if;
end process;

end architecture;