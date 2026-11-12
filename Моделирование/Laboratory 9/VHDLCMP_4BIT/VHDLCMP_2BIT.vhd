library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity VHDLCMP_2BIT is
    port (
        X      : in  STD_LOGIC_VECTOR(1 downto 0);
        Y      : in  STD_LOGIC_VECTOR(1 downto 0);
        XMY0   : in  STD_LOGIC;
        XLY0   : in  STD_LOGIC;
        XEY0   : in  STD_LOGIC;
        XMY    : out STD_LOGIC;
        XLY    : out STD_LOGIC;
        XEY    : out STD_LOGIC
    );
end VHDLCMP_2BIT;

architecture behavioral of VHDLCMP_2BIT is
begin
    process(X, Y, XMY0, XLY0, XEY0)
    begin
        if (X > Y) then
            XMY <= '1';
            XLY <= '0';
            XEY <= '0';
        elsif (X < Y) then
            XMY <= '0';
            XLY <= '1';
            XEY <= '0';
        else 
            XMY <= '0';
            XLY <= '0';
            XEY <= '1';
        end if;
    end process;
end behavioral;