library IEEE;
use IEEE.std_logic_1164.all;

entity decoder_4_16 is
    port ( 
        a  : in  std_logic_vector (3 downto 0);
        en : in  std_logic;
        q  : out std_logic_vector (15 downto 0)
    );
end decoder_4_16;

architecture structural of decoder_4_16 is

    component decoder
        port ( 
            a  : in  std_logic_vector (2 downto 0);
            en : in  std_logic;
            q  : out std_logic_vector (7 downto 0)
        );
    end component;

    signal q_low  : std_logic_vector (7 downto 0);
    signal q_high : std_logic_vector (7 downto 0);
    signal en_low  : std_logic;
    signal en_high : std_logic;

begin

    en_low  <= en and (not a(3));
    en_high <= en and a(3);

    DEC_LOW: decoder port map (
        a  => a(2 downto 0),
        en => en_low,
        q  => q_low
    );

    DEC_HIGH: decoder port map (
        a  => a(2 downto 0), 
        en => en_high,       
        q  => q_high         
    );

    q <= q_high & q_low;

end structural;