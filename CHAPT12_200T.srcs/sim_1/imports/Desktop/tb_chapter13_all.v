`timescale 1ns/1fs

// Teaching-manual Chapter 13 -> chapter12_breakout_200t.xpr.
// Simulation top: tb_chapter13_all. Run 2 ms. Expect CH13 PASS at 1.95 ms.
// Actual hierarchy: dut (game_system_5slot) -> u_game4_breakout.
// All screenshot signals are read-only aliases at this testbench's root.
// Actual pixel-domain clock is 51.2 MHz. The original ball/paddle/brick
// sizes, speeds, 50-brick bitmap, three lives and state codes are retained.
// No force, register deposits, RTL edits, parameter overrides or teleporting.
// Only normal event, pointer and accelerated game_tick inputs are driven.
// The accelerated game_tick is not a measurement of the hardware 60 Hz rate.
// Normal paddle control clears all 50 bricks, including indices 0 and 49.
// This tests the original pitch-cell centre mapping (72x24), as written in
// breakout_game.v; the rendered brick interior is 68x20. It does not assert
// exclusion of a centre point in the four-pixel render gaps.
// calc_* are the original temporary integers. Brick indices retain the last
// query outside the brick region and can be X before the first valid query.
// This is a game-interface test, not PS/2/I2C/MMCM/LCD/board verification.
// Local display copies use the real pixel_x/y==0 condition; this condition
// alone is not a genuine single-cycle LCD frame-start pulse.
// No $finish/$stop: keep the Vivado waveform window open for screenshots.
//
// Figure 13-1 (brick index and one clear): 15.90..16.50 us.
//   game_tick, calc_center_x/y, calc_brick_col/row/index, brick49_alive,
//   brick_alive_live, score_live, bricks_remaining_live, vy_live.
//   First normal collision: centre (828,213), col 9, row 4, index 49.
//   Bit 49: 1->0; score 0->1; remaining 50->49; vy -4->+4.
// Figure 13-2(a) (multiple lives): 39.90..40.25 us; lives 3->2, 1->3->0.
// Figure 13-2(b) (last life): 99.90..100.25 us; lives 1->0, 1->3->5.
//   game_tick, state_live, lives_live, ball_x/y_live, vx_live, vy_live,
//   paddle_x_live. LIFE_LOST lasts one clock, so zoom in to see state 3.
// Decimal for positions/counters/index; Signed Decimal for velocities;
// Binary for pulses/single bits; Hexadecimal for the full brick bitmap.
// States: 0 READY, 1 RUN, 2 PAUSED, 3 LIFE_LOST, 4 WIN, 5 OVER.

module tb_chapter13_all;
    reg clk = 1'b0;
    always #9.765625 clk = ~clk;
    reg rst_n = 1'b0;
    reg [2:0] ui_state_control = 3'd5;
    reg [2:0] ui_state_frame = 3'd5;
    reg event_left = 1'b0;
    reg event_right = 1'b0;
    reg event_ok = 1'b0;
    reg event_back = 1'b0;
    reg event_pause = 1'b0;
    reg game_tick = 1'b0;
    reg [10:0] pointer_x = 11'd512;
    reg [9:0] pointer_y = 10'd300;
    reg pointer_down = 1'b0;
    reg [10:0] pixel_x = 11'd128;
    reg [9:0] pixel_y = 10'd250;
    wire pixel_on;
    wire [23:0] pixel_rgb;
    wire [15:0] score;
    wire [3:0] game_state;
    wire exit_request;

    game_system_5slot dut (
        .clk(clk), .rst_n(rst_n),
        .ui_state_control(ui_state_control), .ui_state_frame(ui_state_frame),
        .event_up(1'b0), .event_down(1'b0),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause), .game_tick(game_tick), .tick_1s(1'b0),
        .pointer_x(pointer_x), .pointer_y(pointer_y), .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .pixel_on(pixel_on),
        .pixel_rgb(pixel_rgb), .score(score), .game_state(game_state),
        .exit_request(exit_request)
    );

    wire [4:0] enable = dut.enable;
    wire game_enable = enable[3];
    wire [3:0] state_live = dut.u_game4_breakout.state_live;
    wire [10:0] ball_x_live = dut.u_game4_breakout.ball_x_live;
    wire [9:0] ball_y_live = dut.u_game4_breakout.ball_y_live;
    wire signed [5:0] vx_live = dut.u_game4_breakout.vx_live;
    wire signed [5:0] vy_live = dut.u_game4_breakout.vy_live;
    wire [10:0] paddle_x_live = dut.u_game4_breakout.paddle_x_live;
    wire [49:0] brick_alive_live = dut.u_game4_breakout.brick_alive_live;
    wire brick49_alive = brick_alive_live[49];
    wire brick0_alive = brick_alive_live[0];
    wire [5:0] bricks_remaining_live = dut.u_game4_breakout.bricks_remaining_live;
    wire [2:0] lives_live = dut.u_game4_breakout.lives_live;
    wire [15:0] score_live = dut.u_game4_breakout.score_live;
    wire signed [31:0] calc_x = dut.u_game4_breakout.calc_x;
    wire signed [31:0] calc_y = dut.u_game4_breakout.calc_y;
    wire signed [31:0] calc_center_x = dut.u_game4_breakout.calc_center_x;
    wire signed [31:0] calc_center_y = dut.u_game4_breakout.calc_center_y;
    wire signed [31:0] calc_brick_col = dut.u_game4_breakout.calc_brick_col;
    wire signed [31:0] calc_brick_row = dut.u_game4_breakout.calc_brick_row;
    wire signed [31:0] calc_brick_index = dut.u_game4_breakout.calc_brick_index;
    wire [10:0] ball_x_frame = dut.u_game4_breakout.ball_x_frame;
    wire [9:0] ball_y_frame = dut.u_game4_breakout.ball_y_frame;
    wire [49:0] brick_alive_frame = dut.u_game4_breakout.brick_alive_frame;

    integer case_id = 0;
    integer errors = 0;
    integer checked_ticks = 0;
    integer ready_tests = 0;
    integer pointer_tests = 0;
    integer pause_tests = 0;
    integer loss_tests = 0;
    integer restart_tests = 0;
    integer win_tests = 0;
    integer left_wall_bounces = 0;
    integer right_wall_bounces = 0;
    integer top_wall_bounces = 0;
    integer paddle_bounces = 0;
    integer cleared_cell_queries = 0;
    integer auto_ticks = 0;
    integer auto_paddle_choices = 0;
    reg index0_cleared = 1'b0;
    reg index49_cleared = 1'b0;
    reg checks_done = 1'b0;
    reg checks_pass = 1'b0;

    task check;
        input condition;
        input [767:0] message;
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("CH13 FAIL at %0.6f us: %0s", $realtime/1000.0, message);
            end
        end
    endtask

    task at_ns;
        input integer target_ns;
        real remaining;
        begin
            remaining = target_ns - $realtime;
            if (remaining > 0) #(remaining);
            @(negedge clk);
        end
    endtask

    // Mask bits: Left, Right, OK, Back, Pause, unused, unused, game_tick.
    task pulse;
        input [7:0] mask;
        begin
            @(negedge clk);
            event_left=mask[0]; event_right=mask[1]; event_ok=mask[2];
            event_back=mask[3]; event_pause=mask[4]; game_tick=mask[7];
            #0.001;
            if (mask[3]) begin
                check(dut.u_game4_breakout.exit_request === game_enable,
                      "breakout Back output was not gated by its slot enable");
                check(exit_request === (|enable), "system Back output missed the selected slot");
            end
            @(negedge clk);
            event_left=0; event_right=0; event_ok=0;
            event_back=0; event_pause=0; game_tick=0;
            #0.001;
        end
    endtask

    task drag;
        input integer x;
        begin
            @(negedge clk); pointer_x=x; pointer_down=1;
            repeat (3) @(negedge clk);
            pointer_down=0; #0.001;
        end
    endtask

    function integer alive_count;
        input [49:0] bitmap;
        integer i;
        begin
            alive_count=0;
            for (i=0; i<50; i=i+1)
                if (bitmap[i] === 1'b1) alive_count=alive_count+1;
        end
    endfunction

    task check_initial;
        begin
            check(state_live==0 && paddle_x_live==456
               && ball_x_live==505 && ball_y_live==522
               && vx_live==4 && vy_live==-4 && lives_live==3
               && brick_alive_live=={50{1'b1}}
               && bricks_remaining_live==50 && score_live==0,
                  "READY/initial ball/paddle/lives/brick bitmap mismatch");
        end
    endtask

    reg [49:0] old_bitmap;
    reg [49:0] removed_bitmap;
    integer old_score;
    integer old_remaining;
    integer old_vx;
    integer old_vy;
    integer removed_count;
    integer row_ref;
    integer col_ref;
    integer index_ref;
    // Check conservation and one-time removal after each real movement tick.
    task tick_checked;
        begin
            check(game_enable && state_live==1, "checked movement tick began outside RUN");
            old_bitmap=brick_alive_live; old_score=score_live;
            old_remaining=bricks_remaining_live; old_vx=vx_live; old_vy=vy_live;
            pulse(8'h80);
            removed_bitmap=old_bitmap & ~brick_alive_live;
            removed_count=alive_count(removed_bitmap);
            check((brick_alive_live & ~old_bitmap)==0 && removed_count<=1,
                  "a movement tick restored bricks or removed more than one");
            check(score_live==old_score+removed_count
               && bricks_remaining_live==old_remaining-removed_count
               && bricks_remaining_live==alive_count(brick_alive_live)
               && score_live+bricks_remaining_live==50,
                  "brick bitmap/score/remaining-count conservation failed");
            check(ball_x_live>=112 && ball_x_live<=898
               && ball_y_live>=64 && ball_y_live<=593,
                  "committed ball position is outside the movement limits");
            check((vx_live==4 || vx_live==-4 || vx_live==6 || vx_live==-6)
               && (vy_live==4 || vy_live==-4), "velocity sign/magnitude mismatch");
            if (calc_center_x>=162 && calc_center_x<882
             && calc_center_y>=96 && calc_center_y<216) begin
                col_ref=(calc_center_x-162)/72;
                row_ref=(calc_center_y-96)/24;
                index_ref=row_ref*10+col_ref;
                check(calc_brick_col==col_ref && calc_brick_row==row_ref
                   && calc_brick_index==index_ref && index_ref>=0 && index_ref<50,
                      "centre-to-brick column/row/index mismatch");
                if (!old_bitmap[index_ref]) begin
                    check(removed_count==0 && score_live==old_score,
                          "an already-cleared brick was scored again");
                    cleared_cell_queries=cleared_cell_queries+1;
                end
            end
            if (removed_count==1) begin
                check(removed_bitmap[calc_brick_index] && vy_live==-old_vy,
                      "brick clear used a different index or failed to reverse vertical speed");
                if (removed_bitmap[0]) index0_cleared=1;
                if (removed_bitmap[49]) index49_cleared=1;
            end
            if (old_vx<0 && vx_live>0 && ball_x_live==112)
                left_wall_bounces=left_wall_bounces+1;
            if (old_vx>0 && vx_live<0 && ball_x_live==898)
                right_wall_bounces=right_wall_bounces+1;
            if (old_vy<0 && vy_live>0 && ball_y_live==64)
                top_wall_bounces=top_wall_bounces+1;
            if (old_vy>0 && vy_live<0 && ball_y_live==522)
                paddle_bounces=paddle_bounces+1;
            checked_ticks=checked_ticks+1;
        end
    endtask

    task ticks;
        input integer count;
        integer i;
        begin
            for (i=0; i<count; i=i+1) begin
                tick_checked();
                repeat (3) @(negedge clk);
            end
            #0.001;
        end
    endtask

    task snapshot_once;
        begin
            @(negedge clk); pixel_x=0; pixel_y=0;
            @(negedge clk); pixel_x=128; pixel_y=250;
            #0.001;
            check(ball_x_frame==ball_x_live && ball_y_frame==ball_y_live
               && brick_alive_frame==brick_alive_live && score==score_live
               && game_state==state_live
               && dut.u_game4_breakout.paddle_x_frame==paddle_x_live
               && dut.u_game4_breakout.lives_frame==lives_live,
                  "local display copy missed a completed game update");
        end
    endtask

    // Move the paddle to the left through its pointer port, let the ball
    // miss naturally, then align the last two downward ticks for screenshots.
    task lose_life;
        input integer loss_ns;
        input integer after_lives;
        integer waited;
        integer before_lives;
        integer held_score;
        reg [49:0] held_bitmap;
        begin
            before_lives=lives_live;
            drag(0);
            waited=0;
            while (state_live==1 && (vy_live<0 || ball_y_live<582) && waited<2000) begin
                ticks(1); waited=waited+1;
            end
            check(state_live==1 && vy_live==4 && ball_y_live==582
               && paddle_x_live==112, "natural falling-ball setup failed");
            check($realtime<loss_ns-1000, "loss setup missed its screenshot time");
            at_ns(loss_ns-1000); tick_checked();
            check(state_live==1 && ball_y_live==586, "penultimate drop tick was not RUN at y=586");
            held_score=score_live; held_bitmap=brick_alive_live;
            at_ns(loss_ns); tick_checked();
            check(state_live==3 && ball_y_live==590 && lives_live==before_lives,
                  "bottom crossing did not enter LIFE_LOST before changing lives");
            @(negedge clk); #0.001;
            check(lives_live==after_lives && state_live==((after_lives==0)?5:0),
                  "LIFE_LOST did not select READY/OVER with exactly one life removed");
            repeat (3) @(negedge clk); #0.001;
            check(lives_live==after_lives && score_live==held_score
               && brick_alive_live==held_bitmap, "one drop removed extra lives or reset bricks/score");
            if (after_lives>0)
                check(ball_x_live==161 && ball_y_live==522 && vx_live==4 && vy_live==-4,
                      "READY after a miss did not reattach the ball/reset its velocity");
            else check(ball_y_live==590, "OVER changed the final missed-ball position");
            loss_tests=loss_tests+1;
        end
    endtask

    reg [31:0] steering_bits=32'h1ACE1234;
    integer predicted_x;
    integer predicted_center;
    integer offset;
    // The helper drives only the same pointer port a user would use.
    // Changing the landing point varies the outgoing +/-6 paddle deflection.
    task clear_all_bricks;
        begin
            auto_ticks=0; steering_bits=32'h1ACE1234;
            while (state_live==1 && auto_ticks<16000) begin
                predicted_x=ball_x_live;
                predicted_x=predicted_x+$signed(vx_live);
                if (predicted_x<112) predicted_x=112;
                else if (predicted_x>898) predicted_x=898;
                predicted_center=predicted_x+7;
                offset=0;
                if (vy_live>0 && ball_y_live>=518) begin
                    steering_bits={steering_bits[30:0],
                        steering_bits[31]^steering_bits[21]^steering_bits[1]^steering_bits[0]};
                    case (steering_bits[1:0])
                        0: offset=28;
                        1: offset=-28;
                        default: offset=0;
                    endcase
                    auto_paddle_choices=auto_paddle_choices+1;
                end
                @(negedge clk); pointer_x=predicted_center+offset; pointer_down=1;
                repeat (2) @(negedge clk);
                tick_checked(); auto_ticks=auto_ticks+1;
            end
            pointer_down=0;
            check(state_live==4 && score_live==50 && bricks_remaining_live==0
               && brick_alive_live==0 && lives_live==3,
                  "normal paddle control failed to clear all 50 bricks without a miss");
            check(index0_cleared && index49_cleared, "edge brick indices 0/49 were not cleared");
            win_tests=win_tests+1;
            $display("CH13 WIN at %0.6f us: score=%0d remaining=%0d auto_ticks=%0d",
                     $realtime/1000.0,score_live,bricks_remaining_live,auto_ticks);
        end
    endtask

    integer held_x;
    integer held_y;
    integer held_paddle;
    reg [49:0] held_bricks;
    initial begin
        at_ns(1000); rst_n=1;
        check_initial();
        check(enable==5'b01000, "fourth-slot selection mismatch");

        at_ns(2000); case_id=1;
        pulse(8'h02); repeat (2) @(negedge clk); #0.001;
        check(paddle_x_live==472 && ball_x_live==521, "READY Right step/attached-ball delay mismatch");
        ready_tests=ready_tests+1;
        pulse(8'h01); repeat (2) @(negedge clk); #0.001;
        check(paddle_x_live==456 && ball_x_live==505, "READY Left step mismatch"); ready_tests=ready_tests+1;
        pulse(8'h03); repeat (2) @(negedge clk); #0.001;
        check(paddle_x_live==440, "simultaneous Left/Right did not prioritize Left"); ready_tests=ready_tests+1;
        pulse(8'h02); repeat (2) @(negedge clk);
        drag(0); check(paddle_x_live==112 && ball_x_live==161, "left pointer clamp failed"); pointer_tests=pointer_tests+1;
        drag(1023); check(paddle_x_live==800 && ball_x_live==849, "right pointer clamp failed"); pointer_tests=pointer_tests+1;
        drag(512); check_initial(); pointer_tests=pointer_tests+1;
        snapshot_once();

        at_ns(4000); pulse(8'h04); check(state_live==1, "OK did not launch the attached ball");
        at_ns(5000); ticks(78);
        check(ball_x_live==817 && ball_y_live==210 && score_live==0,
              "normal flight did not reach the first brick approach");
        at_ns(16000); case_id=2; tick_checked();
        check(calc_center_x==828 && calc_center_y==213
           && calc_brick_col==9 && calc_brick_row==4 && calc_brick_index==49
           && !brick49_alive && score_live==1 && bricks_remaining_live==49
           && vx_live==4 && vy_live==4 && ball_x_live==821 && ball_y_live==206,
              "first natural collision/index-49 clear failed");
        ticks(2);
        check(score_live==1 && bricks_remaining_live==49 && !brick49_alive,
              "the first hit was repeatedly scored on following ticks");
        check(score==0 && brick_alive_frame=={50{1'b1}}, "display changed without a zero-coordinate copy");
        snapshot_once();
        pixel_x=844; pixel_y=202; #0.001;
        check(pixel_rgb==24'h351A20, "cleared brick still rendered as a live brick");
        pixel_x=196; pixel_y=106; #0.001;
        check(pixel_rgb==24'hE3B341, "uncleared row-0 brick color mismatch");
        pixel_x=231; #0.001;
        check(pixel_rgb==24'h351A20, "four-pixel rendered brick gap color mismatch");
        pixel_x=128; pixel_y=250;

        at_ns(20000); case_id=3; pulse(8'h10);
        held_x=ball_x_live; held_y=ball_y_live; held_paddle=paddle_x_live;
        held_bricks=brick_alive_live;
        check(state_live==2, "Pause did not enter PAUSED");
        pulse(8'h83); drag(0); pulse(8'h80);
        check(state_live==2 && ball_x_live==held_x && ball_y_live==held_y
           && paddle_x_live==held_paddle && brick_alive_live==held_bricks
           && score_live==1 && lives_live==3, "PAUSED consumed movement/pointer/tick input");
        snapshot_once();
        at_ns(23000); pulse(8'h04);
        check(state_live==1, "OK did not resume PAUSED"); pause_tests=pause_tests+1;

        at_ns(24000); case_id=4; lose_life(40000,2); // Figure 13-2(a)
        at_ns(45000); pulse(8'h04); case_id=5; lose_life(70000,1);
        at_ns(75000); pulse(8'h04); case_id=6; lose_life(100000,0); // Figure 13-2(b)
        held_x=ball_x_live; held_y=ball_y_live; held_bricks=brick_alive_live;
        pulse(8'h93); drag(1023);
        check(state_live==5 && lives_live==0 && ball_x_live==held_x
           && ball_y_live==held_y && brick_alive_live==held_bricks,
              "OVER consumed movement/pause/pointer/ticks");
        snapshot_once(); pixel_x=512; pixel_y=300; #0.001;
        check(game_state==5 && pixel_rgb==24'hE05252, "OVER overlay/state mismatch");
        pixel_x=128; pixel_y=250;
        at_ns(105000); case_id=7; pulse(8'h04);
        repeat (3) @(negedge clk); #0.001; check_initial(); restart_tests=restart_tests+1;
        snapshot_once();

        at_ns(110000); pulse(8'h04); case_id=8; clear_all_bricks();
        snapshot_once();
        pixel_x=512; pixel_y=300; #0.001;
        check(game_state==4 && score==50 && pixel_rgb==24'h62D394,
              "WIN score/state/overlay or fourth-slot RGB mux mismatch");
        pixel_x=128; pixel_y=250;
        pulse(8'h93); drag(0);
        check(state_live==4 && score_live==50 && brick_alive_live==0,
              "WIN consumed movement/pause/pointer/ticks");

        at_ns(1100000); case_id=9; pulse(8'h04);
        repeat (3) @(negedge clk); #0.001; check_initial(); restart_tests=restart_tests+1;
        snapshot_once();
        pixel_x=505; pixel_y=522; #0.001;
        check(pixel_rgb==24'hFFE16A, "READY attached-ball color mismatch");
        pixel_x=460; pixel_y=540; #0.001;
        check(pixel_rgb==24'hF4F4F4, "paddle color mismatch");
        pixel_x=112; pixel_y=250; #0.001;
        check(pixel_rgb==24'hC45A5A, "field-border color mismatch");
        pixel_x=32; #0.001; check(pixel_rgb==24'h101820, "outside-field color mismatch");
        pixel_x=128; pixel_y=250;

        at_ns(1200000); case_id=10; pulse(8'h08);
        check(state_live==0, "standalone Back changed game state instead of requesting a page exit");
        @(negedge clk); ui_state_control=4;
        pulse(8'h87); repeat (3) @(negedge clk); #0.001;
        check(!game_enable && enable==5'b00100, "breakout remained enabled on another page");
        check_initial(); pulse(8'h08);
        check(!dut.u_game4_breakout.exit_request, "disabled breakout requested exit");
        @(negedge clk); ui_state_control=5;
        pulse(8'h04); check(state_live==1 && score_live==0 && lives_live==3,
                               "page reentry did not start a fresh game");
        at_ns(1300000); case_id=11; rst_n=0; #0.001;
        check_initial();
        check(score==0 && game_state==0 && brick_alive_frame=={50{1'b1}},
              "asynchronous reset failed to restore displayed READY");
        at_ns(1301000); rst_n=1;
        at_ns(1950000);
        check(ready_tests==3 && pointer_tests==3 && pause_tests==1
           && loss_tests==3 && restart_tests==2 && win_tests==1
           && index0_cleared && index49_cleared && cleared_cell_queries>0
           && left_wall_bounces>0 && right_wall_bounces>0
           && top_wall_bounces>0 && paddle_bounces>0,
              "a required launch/wall/brick/life/pause/restart/win case was skipped");
        checks_done=1; checks_pass=(errors==0);
        if (checks_pass)
            $display("CH13 PASS: ticks=%0d losses=%0d win=%0d restarts=%0d cleared_queries=%0d wall_L/R/top=%0d/%0d/%0d paddle=%0d errors=%0d",
                     checked_ticks,loss_tests,win_tests,restart_tests,cleared_cell_queries,
                     left_wall_bounces,right_wall_bounces,top_wall_bounces,paddle_bounces,errors);
        else $display("CH13 FAIL: errors=%0d",errors);
    end
endmodule
