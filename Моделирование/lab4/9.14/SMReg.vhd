library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SMReg is
    Port (
        X1    : in  STD_LOGIC;
        X2    : in  STD_LOGIC;
        X3    : in  STD_LOGIC;
        X4    : in  STD_LOGIC;

        write : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        read  : in  STD_LOGIC;

        Q1    : out STD_LOGIC;
        Q2    : out STD_LOGIC;
        Q3    : out STD_LOGIC;
        Q4    : out STD_LOGIC
    );
end SMReg;

architecture Behavioral of SMReg is
    signal reg_q1 : STD_LOGIC := '0';
    signal reg_q2 : STD_LOGIC := '0';
    signal reg_q3 : STD_LOGIC := '0';
    signal reg_q4 : STD_LOGIC := '0';
begin

    d_flip_flops: process(write, reset)
    begin
        if reset = '0' then
            reg_q1 <= '0';
            reg_q2 <= '0';
            reg_q3 <= '0';
            reg_q4 <= '0';
        elsif rising_edge(write) then
            reg_q1 <= X1;
            reg_q2 <= X2;
            reg_q3 <= X3;
            reg_q4 <= X4;
        end if;
    end process d_flip_flops;

    Q1 <= reg_q1 and read;
    Q2 <= reg_q2 and read;
    Q3 <= reg_q3 and read;
    Q4 <= reg_q4 and read;

end Behavioral;
