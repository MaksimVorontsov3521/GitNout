library ieee;
use ieee.std_logic_1164.all;

entity eo8 is
    port (
        X    : in  std_logic_vector(8 downto 0);
        EVEN : out std_logic;
        ODD  : out std_logic
    );
end eo8;

architecture behavioral of eo8 is
begin
    process(X)
        variable p : std_logic;
    begin
        p := '0';
        for i in X'range loop
            p := p xor X(i);
        end loop;
        ODD  <= p;
        EVEN <= not p;
    end process;
end behavioral;
