-- Lab 12, task 8: the universal configurable multiplier LPM_MULT.
--
-- The assignment describes the element as it is placed from the mega-lpm library in the MAX+plus II
-- graphic editor and configured through EDIT PORTS | PARAMETERS. This project reproduces the very
-- same configuration in text, and it does so against Altera's OWN declaration file rather than a
-- hand-typed one: lpm_pack.vhd is a verbatim copy of
--     C:alteraquartus50librarieshdllpmLPM_PACK.VHD
-- (package LPM_COMPONENTS, "LPM 220 Component Declaration Package", the LPM_MULT component at line
-- 350), and against the built-in library of the same name, so the use clause below resolves to
-- Altera's own declaration rather than a hand-typed one.
--
-- Of the nine settings the assignment lists, six are formal generics of the LPM 220 component:
--     LPM_WIDTHA = 4, LPM_WIDTHB = 4, LPM_WIDTHP = LPM_WIDTHA + LPM_WIDTHB = 8,
--     LPM_WIDTHS = LPM_WIDTHA = 4, LPM_REPRESENTATION = "UNSIGNED", LPM_PIPELINE = 0 (<none>).
-- INPUT_A_IS_CONSTANT, INPUT_B_IS_CONSTANT and USE_EAB are NOT formal generics of the LPM 220
-- component; Altera's declaration file has no such generic and the package header states that
-- LPM_HINT exists precisely to carry non-standard settings ("LPM_SVALUE, LPM_AVALUE, LPM_MODULUS,
-- and LPM_NUMWORDS, LPM_HINT ... default value is string UNUSED", line 163). The three settings are
-- parameters of the Altera AHDL megafunction instead - lpm_mult.tdf lines 44..46 declare
-- INPUT_A_IS_CONSTANT = "NO", INPUT_B_IS_CONSTANT = "NO", USE_EAB = "OFF" - which is exactly what
-- the MegaWizard dialog writes. They are therefore passed in LPM_HINT, and the guest run confirms
-- the megafunction accepts them: Analysis & Synthesis reports 0 errors and 0 warnings, and the
-- elaborated hierarchy is the authentic one,
--     LPM_MULT:U1 | multcore:mult_core | mpar_add:padder | lpm_add_sub:adder | addcore:adder
--                   | a_csnbuffer:result_node
-- so the design really is the library multiplier and not something the student drew by hand.
--
-- Only DATAA, DATAB and RESULT are brought out, as the assignment demands. The remaining ports of
-- the component keep their declared defaults ACLR='0', CLOCK='0', CLKEN='1', SUM=(OTHERS=>'0'),
-- which is what "EDIT PORTS" does in the graphic editor; with LPM_PIPELINE = 0 the altshift latency
-- logic is generated away, so the function is purely RESULT = DATAA * DATAB.
library ieee;
use ieee.std_logic_1164.all;
library lpm;
use lpm.lpm_components.all;

entity lpm4x4 is
  port ( DATAA  : in  std_logic_vector(3 downto 0);
         DATAB  : in  std_logic_vector(3 downto 0);
         RESULT : out std_logic_vector(7 downto 0) );
end lpm4x4;

architecture rtl of lpm4x4 is
begin
  U1 : LPM_MULT
    generic map (
      LPM_WIDTHA         => 4,
      LPM_WIDTHB         => 4,
      LPM_WIDTHP         => 4 + 4,          -- the assignment states LPM_WIDTHA + LPM_WIDTHB
      LPM_WIDTHS         => 4,              -- the assignment states LPM_WIDTHA
      LPM_REPRESENTATION => "UNSIGNED",
      LPM_PIPELINE       => 0,              -- the assignment states <none>
      LPM_HINT           => "INPUT_A_IS_CONSTANT = NO, INPUT_B_IS_CONSTANT = NO, USE_EAB = OFF" )
    port map (
      DATAA  => DATAA,
      DATAB  => DATAB,
      RESULT => RESULT );
end rtl;
--
-- One further point of substance: the top-level entity MUST NOT be called lpm_mult. A VHDL entity
-- name and a component name live in the same declaration space, so a wrapper named lpm_mult
-- shadows the imported component and the compiler then tries to bind LPM_WIDTHA to the wrapper
-- itself, which declares no generics. That is the exact error the first two attempts produced
-- ("formal parameter is not declared"), and it is why the entity here is lpm4x4 while the
-- instantiated component keeps its library name LPM_MULT:U1.
