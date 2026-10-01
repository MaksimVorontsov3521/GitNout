library IEEE;
use IEEE.std_logic_1164.all;

entity shift_reg_1clk is
    port (
        D  : in  std_logic;
        C  : in  std_logic;
        R  : in  std_logic;
        Q1 : out std_logic;
        Q2 : out std_logic
    );
end shift_reg_1clk;

architecture behav of shift_reg_1clk is
    signal tmp : std_logic_vector(1 downto 0);
begin
    process (C, R)
    begin
        if R = '0' then
            tmp <= "00";
        -- ???????? ? rising_edge ?? falling_edge ??? ???????????? ?? ????? C
        elsif falling_edge(C) then
            tmp <= tmp(0) & D;
        end if;
    end process;

    Q1 <= tmp(0);
    Q2 <= tmp(1);
end behav;
