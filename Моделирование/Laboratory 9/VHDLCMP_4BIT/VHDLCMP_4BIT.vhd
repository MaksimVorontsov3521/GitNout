library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity VHDLCMP_4BIT is
    port (
        X      : in  STD_LOGIC_VECTOR(3 downto 0);
        Y      : in  STD_LOGIC_VECTOR(3 downto 0);
        XMY    : out STD_LOGIC;
        XLY    : out STD_LOGIC;
        XEY    : out STD_LOGIC
    );
end VHDLCMP_4BIT;

architecture structural of VHDLCMP_4BIT is

    component VHDLCMP_2BIT
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
    end component;

    signal xmy_low, xly_low, xey_low : STD_LOGIC;

begin

    U1: VHDLCMP_2BIT
        port map (
            X      => X(1 downto 0),
            Y      => Y(1 downto 0),
            XMY0   => '0',
            XLY0   => '0',
            XEY0   => '1',
            XMY    => xmy_low,
            XLY    => xly_low,
            XEY    => xey_low
        );

    U2: VHDLCMP_2BIT
        port map (
            X      => X(3 downto 2),
            Y      => Y(3 downto 2),
            XMY0   => xmy_low,
            XLY0   => xly_low,
            XEY0   => xey_low,
            XMY    => XMY,
            XLY    => XLY,
            XEY    => XEY
        );

end structural;