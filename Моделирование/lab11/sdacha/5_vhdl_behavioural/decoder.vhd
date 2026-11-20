--------------------------------------------------------------------------
-- Work 11 : DECODER of the modified Hamming (8,4) code
-- Quartus II 5.0 (build 148), VHDL-93, ieee.std_logic_1164 only.
--
-- Received codeword, positions 1..8 = IN[7..0].
-- The port is spelled IN_DATA because IN is a reserved word of VHDL-93; the
-- block diagram keeps the plan name IN[7..0]. Same bits, same order, same behaviour.
--   IN7 = K1 | IN6 = K2 | IN5 = D0 | IN4 = K3 | IN3 = D1 | IN2 = D2 | IN1 = D3 | IN0 = K
--   (position 1 -> index 7 ... position 8 -> index 0)
--
-- Syndromes verbatim from the manual (plan 16.1.2):
--   P1 = K1 xor D0 xor D1 xor D3
--   P2 = K2 xor D0 xor D2 xor D3
--   P3 = K3 xor D1 xor D2 xor D3
--   KP = K1 xor K2 xor D0 xor K3 xor D1 xor D2 xor D3 xor K
-- Flags verbatim from the manual:
--   ONE_ERR = KP and (P1 or P2 or P3)
--   DBL_ERR = (not KP) and (P1 or P2 or P3)
--
-- Correction: SYN = P3 & P2 & P1 is the binary number of the faulty position
-- (P1 weight 1, P2 weight 2, P3 weight 4), so the CASE below is the software
-- analogue of the 3-to-8 decoder of the schematic version. Only the
-- information positions 3, 5, 6, 7 are corrected; positions 1, 2, 4, 8
-- (K1, K2, K3, K) leave OUT_DATA untouched. All eight values are listed and
-- "others" covers X/Z on the syndromes.
--
-- Port note: OUT is a reserved word of VHDL, so the data bus is OUT_DATA.
-- OUT_DATA is only written here, never read (Quartus II 5.0 rule).
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity decoder is
  port ( IN_DATA: in  std_logic_vector(7 downto 0);    -- received codeword
         OUT_DATA : out std_logic_vector(3 downto 0);    -- OUT_DATA(0)=D0 .. (3)=D3
         ONE_ERR  : out std_logic;                        -- single error
         DBL_ERR  : out std_logic );                       -- double error
end decoder;

architecture behavioral of decoder is
  signal K1, K2, D0, K3, D1, D2, D3, K : std_logic;       -- received bits
  signal P1, P2, P3                    : std_logic;       -- position syndromes
  signal KP, ANY_P                     : std_logic;       -- parity syndrome, P1+P2+P3
  signal SYN                           : std_logic_vector(2 downto 0);
begin
  -- position 1..8 -> IN7..IN0
  K1 <= IN_DATA(7);   -- position 1
  K2 <= IN_DATA(6);   -- position 2
  D0 <= IN_DATA(5);   -- position 3
  K3 <= IN_DATA(4);   -- position 4
  D1 <= IN_DATA(3);   -- position 5
  D2 <= IN_DATA(2);   -- position 6
  D3 <= IN_DATA(1);   -- position 7
  K  <= IN_DATA(0);   -- position 8

  P1 <= K1 xor D0 xor D1 xor D3;
  P2 <= K2 xor D0 xor D2 xor D3;
  P3 <= K3 xor D1 xor D2 xor D3;
  KP <= K1 xor K2 xor D0 xor K3 xor D1 xor D2 xor D3 xor K;
  ANY_P <= P1 or P2 or P3;

  ONE_ERR <= KP and ANY_P;
  DBL_ERR <= (not KP) and ANY_P;

  SYN <= P3 & P2 & P1;                 -- integer value = faulty position 0..7

  CORRECTION : process (SYN, D0, D1, D2, D3)
    variable F0, F1, F2, F3 : std_logic;                 -- corrected data bits
  begin
    F0 := D0;
    F1 := D1;
    F2 := D2;
    F3 := D3;
    case SYN is
      when "000" => null;                               -- no fault
      when "001" => null;                               -- position 1 = K1, check bit
      when "010" => null;                               -- position 2 = K2, check bit
      when "011" => F0 := D0 xor '1';                   -- position 3 = D0
      when "100" => null;                               -- position 4 = K3, check bit
      when "101" => F1 := D1 xor '1';                   -- position 5 = D1
      when "110" => F2 := D2 xor '1';                   -- position 6 = D2
      when "111" => F3 := D3 xor '1';                   -- position 7 = D3
      when others => null;                              -- X / Z on the syndromes
    end case;
    OUT_DATA <= F3 & F2 & F1 & F0;                       -- (3)=D3 .. (0)=D0
  end process;
end behavioral;
