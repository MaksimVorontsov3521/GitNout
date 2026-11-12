library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CMP_2BIT is
    port (
        X      : in  STD_LOGIC_VECTOR(1 downto 0);
        Y      : in  STD_LOGIC_VECTOR(1 downto 0);
        XMI0   : in  STD_LOGIC;
        XLI0   : in  STD_LOGIC;
        XEI0   : in  STD_LOGIC;
        XMY    : out STD_LOGIC;
        XLY    : out STD_LOGIC;
        XEY    : out STD_LOGIC
    );
end CMP_2BIT;

architecture rtl of CMP_2BIT is
    signal cmp_result : STD_LOGIC_VECTOR(1 downto 0);
begin
    process(X, Y)
    begin
        if (X > Y) then
            cmp_result <= "10";
        elsif (X < Y) then
            cmp_result <= "01";
        else
            cmp_result <= "00";
        end if;
    end process;

    XMY <= cmp_result(1) when cmp_result(1) = '1' else XMI0;
    XLY <= cmp_result(0) when cmp_result(0) = '1' else XLI0;
    XEY <= '1' when (cmp_result = "00" and XEI0 = '1') else '0';
end rtl;