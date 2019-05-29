/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

module bp_core
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p
                                ,paddr_width_p
                                ,asid_width_p
                                ,branch_metadata_fwd_width_p
                                )
    `declare_bp_lce_cce_if_widths(num_cce_p
                                  ,num_lce_p
                                  ,paddr_width_p
                                  ,lce_assoc_p
                                  ,dword_width_p
                                  ,cce_block_width_p
                                  )
    , parameter calc_trace_p = 0

    // Should go away with manycore bridge 
    , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
    )
   (
    input                                          clk_i
    , input                                        reset_i
    , input                                        freeze_i

    , input [proc_cfg_width_lp-1:0]                proc_cfg_i

    // LCE-CCE interface
    , output [1:0][lce_cce_req_width_lp-1:0]       lce_req_o
    , output [1:0]                                 lce_req_v_o
    , input [1:0]                                  lce_req_ready_i

    , output [1:0][lce_cce_resp_width_lp-1:0]      lce_resp_o
    , output [1:0]                                 lce_resp_v_o
    , input [1:0]                                  lce_resp_ready_i

    , output [1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
    , output [1:0]                                 lce_data_resp_v_o
    , input [1:0]                                  lce_data_resp_ready_i

    // CCE-LCE interface
    , input [1:0][cce_lce_cmd_width_lp-1:0]        lce_cmd_i
    , input [1:0]                                  lce_cmd_v_i
    , output [1:0]                                 lce_cmd_ready_o

    , input [1:0][lce_data_cmd_width_lp-1:0]       lce_data_cmd_i
    , input [1:0]                                  lce_data_cmd_v_i
    , output [1:0]                                 lce_data_cmd_ready_o

    , output [1:0][lce_data_cmd_width_lp-1:0]      lce_data_cmd_o
    , output [1:0]                                 lce_data_cmd_v_o
    , input [1:0]                                  lce_data_cmd_ready_i

    , input                                        timer_int_i
    , input                                        software_int_i
    , input                                        external_int_i

    // config link
    , input [bp_cfg_link_addr_width_gp-2:0]           config_addr_i
    , input [bp_cfg_link_data_width_gp-1:0]           config_data_i
    , input                                           config_v_i
    , input                                           config_w_i
    , output logic                                    config_ready_o
 
    , output logic [bp_cfg_link_data_width_gp-1:0]    config_data_o
    , output logic                                    config_v_o
    , input                                           config_ready_i
    );

  `declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
  `declare_bp_fe_be_if(vaddr_width_p
                       ,paddr_width_p
                       ,asid_width_p
                       ,branch_metadata_fwd_width_p
                       );

  bp_fe_queue_s fe_queue_li, fe_queue_lo;
  logic fe_queue_v_li, fe_queue_ready_lo;
  logic fe_queue_v_lo, fe_queue_ready_li;

  logic fe_queue_clr_li, fe_queue_dequeue_li, fe_queue_rollback_li;

  bp_fe_cmd_s fe_cmd_li, fe_cmd_lo;
  logic fe_cmd_v_li, fe_cmd_ready_lo;
  logic fe_cmd_v_lo, fe_cmd_ready_li;

  bp_proc_cfg_s proc_cfg;
  assign proc_cfg = proc_cfg_i;
  bp_fe_top
   #(.cfg_p(cfg_p))
   fe 
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.icache_id_i(proc_cfg.icache_id)

     ,.fe_queue_o(fe_queue_li)
     ,.fe_queue_v_o(fe_queue_v_li)
     ,.fe_queue_ready_i(fe_queue_ready_lo)

     ,.fe_cmd_i(fe_cmd_lo)
     ,.fe_cmd_v_i(fe_cmd_v_lo)
     ,.fe_cmd_ready_o(fe_cmd_ready_li)

     ,.lce_req_o(lce_req_o[0])
     ,.lce_req_v_o(lce_req_v_o[0])
     ,.lce_req_ready_i(lce_req_ready_i[0])

     ,.lce_resp_o(lce_resp_o[0])
     ,.lce_resp_v_o(lce_resp_v_o[0])
     ,.lce_resp_ready_i(lce_resp_ready_i[0])

     ,.lce_data_resp_o(lce_data_resp_o[0])
     ,.lce_data_resp_v_o(lce_data_resp_v_o[0])
     ,.lce_data_resp_ready_i(lce_data_resp_ready_i[0])

     ,.lce_cmd_i(lce_cmd_i[0])
     ,.lce_cmd_v_i(lce_cmd_v_i[0])
     ,.lce_cmd_ready_o(lce_cmd_ready_o[0])

     ,.lce_data_cmd_i(lce_data_cmd_i[0])
     ,.lce_data_cmd_v_i(lce_data_cmd_v_i[0])
     ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o[0])

     ,.lce_data_cmd_o(lce_data_cmd_o[0])
     ,.lce_data_cmd_v_o(lce_data_cmd_v_o[0])
     ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i[0])
     );

  bsg_fifo_1r1w_rolly 
   #(.width_p(fe_queue_width_lp)
     ,.els_p(fe_queue_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   fe_queue_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clr_v_i(fe_queue_clr_li)
     ,.ckpt_v_i(fe_queue_dequeue_li)
     ,.roll_v_i(fe_queue_rollback_li)

     ,.data_i(fe_queue_li)
     ,.v_i(fe_queue_v_li)
     ,.ready_o(fe_queue_ready_lo)

     ,.data_o(fe_queue_lo)
     ,.v_o(fe_queue_v_lo)
     ,.yumi_i(fe_queue_ready_li)
     );

  bsg_fifo_1r1w_fence
   #(.width_p(fe_cmd_width_lp)
     ,.els_p(fe_cmd_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
      
     // FE cmd fencing is not implemented at the moment     
     ,.fence_set_i(1'b0)
     ,.fence_clr_i(1'b0)
     ,.fence_o()

     ,.data_i(fe_cmd_li)
     ,.v_i(fe_cmd_v_li)
     ,.ready_o(fe_cmd_ready_lo)
                  
     ,.data_o(fe_cmd_lo)
     ,.v_o(fe_cmd_v_lo)
     ,.yumi_i(fe_cmd_ready_li)
     );

  bp_be_top 
   #(.cfg_p(cfg_p)
     ,.calc_trace_p(calc_trace_p)
     )
   be
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.freeze_i(freeze_i)

     ,.proc_cfg_i(proc_cfg_i)

     ,.fe_queue_i(fe_queue_lo)
     ,.fe_queue_v_i(fe_queue_v_lo)
     ,.fe_queue_ready_o(fe_queue_ready_li)

     ,.fe_queue_clr_o(fe_queue_clr_li)
     ,.fe_queue_dequeue_o(fe_queue_dequeue_li)
     ,.fe_queue_rollback_o(fe_queue_rollback_li)

     ,.fe_cmd_o(fe_cmd_li)
     ,.fe_cmd_v_o(fe_cmd_v_li)
     ,.fe_cmd_ready_i(fe_cmd_ready_lo)

     ,.lce_req_o(lce_req_o[1])
     ,.lce_req_v_o(lce_req_v_o[1])
     ,.lce_req_ready_i(lce_req_ready_i[1])

     ,.lce_resp_o(lce_resp_o[1])
     ,.lce_resp_v_o(lce_resp_v_o[1])
     ,.lce_resp_ready_i(lce_resp_ready_i[1])

     ,.lce_data_resp_o(lce_data_resp_o[1])
     ,.lce_data_resp_v_o(lce_data_resp_v_o[1])
     ,.lce_data_resp_ready_i(lce_data_resp_ready_i[1])

     ,.lce_cmd_i(lce_cmd_i[1])
     ,.lce_cmd_v_i(lce_cmd_v_i[1])
     ,.lce_cmd_ready_o(lce_cmd_ready_o[1])

     ,.lce_data_cmd_i(lce_data_cmd_i[1])
     ,.lce_data_cmd_v_i(lce_data_cmd_v_i[1])
     ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o[1])

     ,.lce_data_cmd_o(lce_data_cmd_o[1])
     ,.lce_data_cmd_v_o(lce_data_cmd_v_o[1])
     ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i[1])

     ,.timer_int_i(timer_int_i)
     ,.software_int_i(software_int_i)
     ,.external_int_i(external_int_i)

     ,.config_addr_i(config_addr_i)
     ,.config_data_i(config_data_i)
     ,.config_v_i(config_v_i)
     ,.config_w_i(config_w_i)
     ,.config_ready_o(config_ready_o)
 
     ,.config_data_o(config_data_o)
     ,.config_v_o(config_v_o)
     ,.config_ready_i(config_ready_i)
     );

endmodule : bp_core

