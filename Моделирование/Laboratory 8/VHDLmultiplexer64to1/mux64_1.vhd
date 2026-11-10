library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity mux64_1 is
    Port ( 
        x   : in  STD_LOGIC_VECTOR(63 downto 0);
        a   : in  STD_LOGIC_VECTOR(5 downto 0);
        E   : in  STD_LOGIC;
        Q   : out STD_LOGIC;
        Q_n : out STD_LOGIC
    );
end mux64_1;

architecture Structural of mux64_1 is

    component mux4_1
        Port ( 
            x   : in  STD_LOGIC_VECTOR(3 downto 0); 
            a   : in  STD_LOGIC_VECTOR(1 downto 0); 
            E   : in  STD_LOGIC;                    
            Q   : out STD_LOGIC;
            Q_n : out STD_LOGIC
        );
    end component;

    signal level1_out : STD_LOGIC_VECTOR(15 downto 0);
    signal level2_out : STD_LOGIC_VECTOR(3 downto 0);

begin

    GEN_LEVEL1: for i in 0 to 15 generate
        U_L1: mux4_1 port map(
            x   => x(i*4 + 3 downto i*4),
            a   => a(1 downto 0),
            E   => E,
            Q   => level1_out(i),
            Q_n => open
        );
    end generate;

    GEN_LEVEL2: for i in 0 to 3 generate
        U_L2: mux4_1 port map(
            x   => level1_out(i*4 + 3 downto i*4),
            a   => a(3 downto 2),
            E   => E,
            Q   => level2_out(i),
            Q_n => open
        );
    end generate;


    U_L3: mux4_1 port map(
        x   => level2_out(3 downto 0),
        a   => a(5 downto 4),
        E   => E,
        Q   => Q,
        Q_n => Q_n
    );

end Structural;