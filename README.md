# FPGA-Data-Acquisition-Statistics-System---Complete-VHDL-Implementation
📱 Key Features:
•4×4 keypad interface with robust debouncing
•32-entry RAM storage for BCD data
•Statistics computation (MIN, MAX, AVG, COUNT)
•4-digit multiplexed 7-segment display output
•Intelligent display switching with timeout logic

🔄 System Flow:
Keypad Input→ BCD Processing → RAM Storage → Statistics Engine → Display Output

🎯 Technical Highlights:
•Target: EP4CE6E22C8N FPGA (Cyclone IV)
•Clock: 50MHz with multiple derived timing domains
•Robust error handling (saturation, division protection, range checking)
•Efficient resource utilization (~8% of target FPGA)

This project demonstrates how digital logic design principles can create complete embedded systems without microcontrollers, bridging hardware interfacing with computational processing.

💡 Key Learnings:
•Practical VHDL coding for real-world applications
•System-level integration of multiple functional blocks
•Trade-off analysis between resource usage and performance
•Robust design with comprehensive error prevention
