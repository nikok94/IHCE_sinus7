LIBRARY ieee;
USE ieee.std_logic_1164.all;

library work;
use work.Controller_RAM32;

ENTITY Controller_RAM32x256 IS
    port
    (
      clk       : in std_logic;
      rst       : in std_logic;
    -- aly bus
      s_addr      : in std_logic_vector(2 downto 0);

      s_wr_en     : in std_logic;
      s_wr_ack    : out std_logic;
      s_wr_data   : in std_logic_vector(31 downto 0);

      s_rd_en     : in std_logic;
      s_rd_data   : out std_logic_vector(31 downto 0);
      s_rd_ack    : out std_logic;
    -- out registr 256
      out_data_reg  : out std_logic_vector(255 downto 0);
      next_reg      : in std_logic
    );
END Controller_RAM32x256;

ARCHITECTURE Controller_RAM32x256_arh OF Controller_RAM32x256 IS
    signal wr_en_reg    : std_logic_vector(7 downto 0):= (others => '0');
    signal vcc          : std_logic:= '1';
    signal gnd          : std_logic:= '0';
    signal data256_reg  : std_logic_vector(255 downto 0);

begin 
out_data_reg <= data256_reg;

rd_wr_ack_proc :
    process(clk, s_wr_en, s_rd_en)
    begin
      if rising_edge(clk) then
        if (s_wr_en = '1') then
          s_wr_ack <= '1';
        else
          s_wr_ack <= '0';
        end if;
        if (s_rd_en = '1') then
          s_rd_ack <= '1';
        else 
          s_rd_ack <= '0';
        end if;
      end if;
    end process;

wr_en_reg_proc :
    process(clk)
    begin
      if rising_edge(clk) then
        if (s_wr_en = '1') then
          case (s_addr) is
            when b"000" => 
                  wr_en_reg(0) <= vcc;
            when b"001" => 
                  wr_en_reg(1) <= vcc;
            when b"010" => 
                  wr_en_reg(2) <= vcc;
            when b"011" => 
                  wr_en_reg(3) <= vcc;
            when b"100" => 
                  wr_en_reg(4) <= vcc;
            when b"101" => 
                  wr_en_reg(5) <= vcc;
            when b"110" => 
                  wr_en_reg(6) <= vcc;
            when b"111" => 
                  wr_en_reg(7) <= vcc;
            when others => wr_en_reg <= (others => gnd);
          end case;
        else
          wr_en_reg <= (others => gnd);
        end if;
      end if;
    end process;


ram32to256_gen : for i in 0 to 7 generate
RAM32_inst  : entity work.Controller_RAM32
    port map
    (
      clk       => clk,
      rst       => rst,
      wr_en     => wr_en_reg(i),
      wr_data   => s_wr_data,

      rd_en     => next_reg,
      rd_data   => data256_reg(32*i+31 downto 32*i)
    );
end generate ram32to256_gen;

END Controller_RAM32x256_arh;