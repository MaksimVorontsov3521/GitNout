Libary ieee;
Use ieee.std_logic_1164.All;

Entity notand IS
PORT (a : IN std_logic
b : IN std_logic;
c : OUT std_logic );
End notand;

ARCHITECTURE behavior OF notand IS
BEGIN
c<= NOT (a AND b);
End behavior;