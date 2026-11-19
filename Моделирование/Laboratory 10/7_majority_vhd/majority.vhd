library ieee;
use ieee.std_logic_1164.all;

entity majority is
    port (
        X1, X2, X3 : in  std_logic;
        M          : out std_logic;
        a1, a0     : out std_logic
    );
end majority;

architecture behavioral of majority is
begin
    process(X1, X2, X3)
        variable vv : std_logic_vector(2 downto 0);
        variable n  : integer;
    begin
        vv := X1 & X2 & X3;
        n := 0;
        for i in vv'range loop
            if vv(i) = '1' then
                n := n + 1;
            end if;
        end loop;

        if n >= 2 then M <= '1'; else M <= '0'; end if;

        case vv is
            when "100" | "011" => a1 <= '0'; a0 <= '1';
            when "010" | "101" => a1 <= '1'; a0 <= '0';
            when "001" | "110" => a1 <= '1'; a0 <= '1';
            when others        => a1 <= '0'; a0 <= '0';
        end case;
    end process;
end behavioral;
