library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Counter4_synth is
    Port ( CLK   : in  STD_LOGIC;
           RST_N : in  STD_LOGIC;
           EN    : in  STD_LOGIC;
           Q     : out STD_LOGIC_VECTOR(3 downto 0));
end Counter4_synth;

architecture RTL of Counter4_synth is
    signal cnt : unsigned(3 downto 0);
begin
    process(CLK, RST_N)
    begin
        if RST_N = '0' then
            cnt <= (others => '0');
        elsif rising_edge(CLK) then
            if EN = '1' then
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    Q <= std_logic_vector(cnt);
end RTL;