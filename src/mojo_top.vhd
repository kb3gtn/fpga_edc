library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mojo_top is
    Port ( 
        clk50m              : in  STD_LOGIC;
        rst_n               : in  STD_LOGIC;
        cclk                : in  STD_LOGIC; -- spi/fpga programming clock (not used).
        led                 : out  STD_LOGIC_VECTOR (7 downto 0); -- board LEDs

        -- spi interface shared with AVR and SPI flash chip (not used here)
        --spi_mosi    : in  STD_LOGIC;
        --spi_miso    : out  STD_LOGIC;
        --spi_ss      : in  STD_LOGIC;
        --spi_sck     : in  STD_LOGIC;
        --spi_channel : in  STD_LOGIC_VECTOR (3 downto 0); ( not used here)

        -- avr rs232 interface (ttl levels) ( not used here )
        -- avr_tx      : in  STD_LOGIC;
        -- avr_rx      : in  STD_LOGIC;
        -- avr_rx_busy : in  STD_LOGIC

        -- RS232
        serial_tx   : out STD_LOGIC;  -- 3rd pin up from uC outside.
        serial_rx   : in  STD_LOGIC;   -- 4th pin up from uC outside.

        -- SPI1 signals
        spi1_miso   : in  STD_LOGIC;
        spi1_mosi   : out STD_LOGIC;
        spi1_sclk   : out STD_LOGIC;
        spi1_cs_n   : out STD_LOGIC_VECTOR( 3 downto 0)

    );
end mojo_top;

architecture Behavioral of mojo_top is

    --#########################################################
    --# Component Definitions
    --#########################################################

    component uart is
    port (
        i_clk               : in    std_logic;  -- system clock
        i_srst              : in    std_logic;  -- synchronious reset, 1 - active
        i_baud_div          : in    std_logic_vector(15 downto 0);  -- clk divider to get to baud rate
        -- uart interface
        o_uart_tx           : out   std_logic;  -- tx bit stream
        i_uart_rx           : in    std_logic;  -- uart rx bit stream input
        -- fpga side
        i_tx_send             : in    std_logic_vector(7 downto 0); -- data byte in
        i_tx_send_we          : in    std_logic;  -- write enable
        o_tx_send_busy        : out   std_logic;  -- tx is busy, writes are ignored.
        o_rx_read             : out   std_logic_vector(7 downto 0); -- data byte out
        o_rx_read_valid       : out   std_logic;  -- read data valid this clock cycle
        i_rx_read_rd          : in    std_logic  -- read request, get next byte..
    );
    end component uart;

    component uart_db_interface is
    port (
        i_clk                   : in    std_logic;     -- input system clock
        i_srst                  : in    std_logic;     -- sync reset to system clock
        -- uart interface
        i_rx_data               : in    std_logic_vector( 7 downto 0);  -- data from uart
        i_rx_data_valid         : in    std_logic;     -- valid data from uart
        o_rx_read_ack           : out   std_logic;     -- tell uart we have read byte.
        o_tx_send               : out   std_logic_vector( 7 downto 0); -- tx_send data
        o_tx_send_wstrb         : out   std_logic;     -- write data strobe
        i_tx_send_busy          : in    std_logic;     -- uart is busy tx, don't write anything.. (stall)
        -- databus master interface
        o_db_cmd_wstrb          : out   std_logic;     -- write command strobe
        o_db_cmd_out            : out   std_logic_vector( 7 downto 0); -- cmd to databus master
        o_db_cmd_data_out       : out   std_logic_vector( 7 downto 0); -- write data to databus master
        i_db_cmd_data_in        : in    std_logic_vector( 7 downto 0); -- read data from databus master
        i_db_cmd_rdy            : in    std_logic  -- db is ready to process a cmd / previous cmd is complete.
    );
    end component;

    component databus_master is
    generic (
        slave_latency_max   : integer := 3       -- latency from read/write strb to when the 
                                                 -- operation is complete in number of i_clk cycles.
                                                 -- 3 would give a slave 3 clock cycles to perform 
                                                 -- the needed operation.
    );
    port (
        -- clock and resets
        i_clk               : in    std_logic;                      -- input system clock
        i_srst              : in    std_logic;                      -- sync reset to system clock
        -- db master cmd interface
        i_db_cmd_in         : in    std_logic_vector( 7 downto 0);  -- input cmd byte
        i_db_cmd_wstrb      : in    std_logic;                      -- write strobe for cmd byte
        o_db_cmd_rdy        : out   std_logic;                      -- '1' rdy to process next cmd, '0' busy
        i_db_cmd_data_in    : in    std_logic_vector( 7 downto 0);  -- input byte if cmd is a write (with wstrb)
        o_db_cmd_data_out   : out   std_logic_vector( 7 downto 0);  -- output byte if cmd was a read
        -- data bus interface
        o_db_addr           : out   std_logic_vector( 6 downto 0);  -- 6 -> 0 bit address bus (7 bits)
        o_db_write_data     : out   std_logic_vector( 7 downto 0);  -- write data 
        i_db_read_data      : in    std_logic_vector( 7 downto 0);  -- read data
        o_db_read_strb      : out   std_logic;                      -- db_read_strobe
        o_db_write_strb     : out   std_logic                       -- db_write_strobe
    );
    end component;

    component spi_master is
    generic (
        -- default address for this module to use..
        data_reg_addr       : std_logic_vector( 6 downto 0) := "0000000";  -- address 0
        conf_reg_addr       : std_logic_vector( 6 downto 0) := "0000001";  -- address 1
        baud_reg_addr       : std_logic_vector( 6 downto 0) := "0000010"   -- address 2
    );
    port (
        i_clk               : in    std_logic;  -- input system clock (50 MHz)
        i_srst              : in    std_logic;  -- input sync reset to i_clk
        -- spi interface   
        o_spi_sclk          : out   std_logic;  -- spi clock signal
        o_spi_mosi          : out   std_logic;  -- spi master data output
        i_spi_miso          : in    std_logic;  -- spi master data input
        o_spi_cs_n          : out   std_logic_vector( 3 downto 0); -- chip select signals. (active low)
        -- data bus interface
        i_db_addr           : in    std_logic_vector( 6 downto 0);
        i_db_wr_strb        : in    std_logic;
        i_db_rd_strb        : in    std_logic;
        i_db_wr_data        : in    std_logic_vector( 7 downto 0 );
        o_db_rd_data        : out   std_logic_vector( 7 downto 0 )
    );
    end component;


    --###########################################################
    --# Signal Definitions
    --###########################################################
    
    -- uart signals
    signal baud_div          : std_logic_vector( 15 downto 0);
    signal tx_byte           : std_logic_vector( 7 downto 0);
    signal tx_byte_we        : std_logic;
    signal tx_byte_busy      : std_logic;
    signal rx_byte           : std_logic_vector( 7 downto 0);
    signal rx_byte_valid     : std_logic;
    signal rx_byte_rd        : std_logic;

    -- data bus master signals
    signal db_cmd            : std_logic_vector( 7 downto 0 );
    signal db_cmd_wstrb      : std_logic;
    signal db_cmd_rdy        : std_logic;
    signal db_cmd_wr_data    : std_logic_vector( 7 downto 0 );
    signal db_cmd_rd_data    : std_logic_vector( 7 downto 0 );

    -- data bus interface to slaves
    signal db_addr           : std_logic_vector(6 downto 0);
    signal db_wr_data        : std_logic_vector(7 downto 0);
    signal db_rd_data        : std_logic_vector(7 downto 0);
    signal db_wr_strb        : std_logic;
    signal db_rd_strb        : std_logic;

    -- output register for driving the LEDs
    signal led_reg          : std_logic_vector(7 downto 0);

    -- sync reset signal to 50 MHz clk
    signal srst             : std_logic;

begin

    led <= led_reg;
    -- led <= rx_byte;


    baud_div <= x"01B2";  -- 115200

    uart_1 : uart 
    port map (
        i_clk                   => clk50m,
        i_srst                  => srst,
        i_baud_div              => baud_div,
        -- uart interface
        o_uart_tx               => serial_tx,
        i_uart_rx               => serial_rx,
        -- fpga side
        i_tx_send               => tx_byte,
        i_tx_send_we            => tx_byte_we,
        o_tx_send_busy          => tx_byte_busy,
        o_rx_read               => rx_byte,
        o_rx_read_valid         => rx_byte_valid,
        i_rx_read_rd            => rx_byte_rd
    );

    udbi_1 : uart_db_interface
    port map (
        i_clk                   => clk50m, 
        i_srst                  => srst,
        -- uart interface
        i_rx_data               => rx_byte,
        i_rx_data_valid         => rx_byte_valid,
        o_rx_read_ack           => rx_byte_rd,
        o_tx_send               => tx_byte,
        o_tx_send_wstrb         => tx_byte_we,
        i_tx_send_busy          => tx_byte_busy,
        -- databus master interface
        o_db_cmd_wstrb          => db_cmd_wstrb,
        o_db_cmd_out            => db_cmd,
        o_db_cmd_data_out       => db_cmd_wr_data,
        i_db_cmd_data_in        => db_cmd_rd_data,
        i_db_cmd_rdy            => db_cmd_rdy
    );


    db_master_1 : databus_master
    generic map (
        slave_latency_max    => 3                -- latency from read/write strb to when the 
                                                 -- operation is complete in number of i_clk cycles.
                                                 -- 3 would give a slave 3 clock cycles to perform 
                                                 -- the needed operation.
    )
    port map (
        -- clock and resets
        i_clk                 => clk50m,   
        i_srst                => srst,
        -- db master cmd interface
        i_db_cmd_in           => db_cmd,
        i_db_cmd_wstrb        => db_cmd_wstrb,
        o_db_cmd_rdy          => db_cmd_rdy,
        i_db_cmd_data_in      => db_cmd_wr_data,
        o_db_cmd_data_out     => db_cmd_rd_data,
        -- data bus interface
        o_db_addr             => db_addr,
        o_db_write_data       => db_wr_data,
        i_db_read_data        => db_rd_data,
        o_db_read_strb        => db_rd_strb,
        o_db_write_strb       => db_wr_strb
    );


    -- generate synchronious reset signal for
    -- synchronious blocks
    rst_sync : process( clk50m )
    begin
        if ( rising_edge(clk50m) ) then
            if ( rst_n = '0' ) then
                -- reset active
                srst <= '1';
                -- for now, just hardcode the nco rate at startup
                -- 0x1AE ~= 10 Hz rate.. (10.0117176818 Hz)
                -- freq = (nco_ftw / 2^31-1)*50e6
                -- nco_ftw = ( Freq / 50e6 ) * (2^31-1)
                -- nco_ftw <= x"000001AE";
            else
                srst <= '0';
            end if;
        end if;
    end process;


    spi_master_1 : spi_master
    generic map (
        -- default address for this module to use..
        data_reg_addr       => "0000000",  -- address 0
        conf_reg_addr       => "0000001",  -- address 1
        baud_reg_addr       => "0000010"   -- address 2
    )
    port map (
        i_clk               => clk50m,
        i_srst              => srst,
        -- spi interface   
        o_spi_sclk          => spi1_sclk,
        o_spi_mosi          => spi1_mosi,
        i_spi_miso          => spi1_miso,
        o_spi_cs_n          => spi1_cs_n,
        -- data bus interface
        i_db_addr           => db_addr,
        i_db_wr_strb        => db_wr_strb,
        i_db_rd_strb        => db_rd_strb,
        i_db_wr_data        => db_wr_data,
        o_db_rd_data        => db_rd_data 
    );

    
    -- simple data bus slave to control LEDs on address 3
    led_ctrl : process( clk50m )
    begin
        if ( rising_edge( clk50m ) ) then
            if ( srst = '1' ) then
                led_reg <= (others=>'0');
            else
                if ( db_wr_strb = '1' ) then
                    -- if address 0x03
                    if ( db_addr = "0000011" ) then
                        led_reg <= db_wr_data;
                    end if;
                end if;
                if ( db_rd_strb = '1' ) then
                    if ( db_addr = "0000011" ) then 
                        db_rd_data <= led_reg;
                    end if;
                else
                    db_rd_data <= (others=>'Z');
                end if;
            end if;
        end if;
    end process;
                

end architecture;

