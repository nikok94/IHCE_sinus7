LIBRARY ieee;
USE ieee.std_logic_1164.all;

library proc_common_pkg;
use proc_common_pkg.clog2;

ENTITY Controller_RAM32 IS
    generic(
      c_addr_width  : integer := 7
    );

    port
    (
      clk       : in std_logic;
      rst       : in std_logic;
      addr      : in std_logic_vector(clog2(c_addr_width)-1 downto 0);

      wr_en     : in std_logic;
      wr_data   : in std_logic_vector(31 downto 0);

      rd_en     : in std_logic;
      rd_data   : out std_logic_vector(31 downto 0)
    );
END Controller_RAM32;