`timescale 1ns / 1ps

module axis_upsizer_32_128 (
    input  wire         aclk,
    input  wire         aresetn, // Active Low Reset

    // Slave Interface (32-bit Input)
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tlast,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,

    // Master Interface (128-bit Output)
    output reg  [127:0] m_axis_tdata,
    output reg          m_axis_tlast,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready
);

    //=========================================================================
    // 内部レジスタと状態定義
    //=========================================================================
    // 受信したデータを一時保存するバッファ (最大3ワード分 = 96bit)
    // 4ワード目は直接出力に結合するため、バッファは3つで十分です
    reg [95:0] stored_data;
    
    // 現在いくつのワードが溜まったかを数えるカウンタ (0～3)
    reg [1:0]  word_cnt;

    //=========================================================================
    // Ready信号の生成
    //=========================================================================
    // 以下のいずれかの時にデータを受け入れ可能
    // 1. 出力バッファが空 (Valid=0)
    // 2. 出力先にデータを受け取ってもらえる (Ready=1)
    assign s_axis_tready = (!m_axis_tvalid || m_axis_tready);

    //=========================================================================
    // データパスと制御ロジック
    //=========================================================================
    always @(posedge aclk) begin
        if (!aresetn) begin
            word_cnt      <= 2'd0;
            stored_data   <= 96'd0;
            m_axis_tdata  <= 128'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            // ハンドシェイク完了時の処理: Validを下げる
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            // 新しいデータの取り込み
            if (s_axis_tvalid && s_axis_tready) begin
                case (word_cnt)
                    //---------------------------------------------------------
                    // 1ワード目 (0-31 bit)
                    //---------------------------------------------------------
                    2'd0: begin
                        if (s_axis_tlast) begin
                            // TLASTが来た -> 残りを0埋めして即出力
                            m_axis_tdata  <= {96'd0, s_axis_tdata};
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= 1'b1;
                            word_cnt      <= 2'd0; // カウンタリセット
                        end else begin
                            // 次のデータを待つ
                            stored_data[31:0] <= s_axis_tdata;
                            word_cnt          <= 2'd1;
                        end
                    end

                    //---------------------------------------------------------
                    // 2ワード目 (32-63 bit)
                    //---------------------------------------------------------
                    2'd1: begin
                        if (s_axis_tlast) begin
                            // TLASTが来た -> 残りを0埋めして即出力
                            // [Zero padding] + [Current] + [Stored 0]
                            m_axis_tdata  <= {64'd0, s_axis_tdata, stored_data[31:0]};
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= 1'b1;
                            word_cnt      <= 2'd0;
                        end else begin
                            stored_data[63:32] <= s_axis_tdata;
                            word_cnt           <= 2'd2;
                        end
                    end

                    //---------------------------------------------------------
                    // 3ワード目 (64-95 bit)
                    //---------------------------------------------------------
                    2'd2: begin
                        if (s_axis_tlast) begin
                            // TLASTが来た -> 残りを0埋めして即出力
                            // [Zero padding] + [Current] + [Stored 1] + [Stored 0]
                            m_axis_tdata  <= {32'd0, s_axis_tdata, stored_data[63:0]};
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= 1'b1;
                            word_cnt      <= 2'd0;
                        end else begin
                            stored_data[95:64] <= s_axis_tdata;
                            word_cnt           <= 2'd3;
                        end
                    end

                    //---------------------------------------------------------
                    // 4ワード目 (96-127 bit) - 完了
                    //---------------------------------------------------------
                    2'd3: begin
                        // 4ワード揃ったので結合して出力
                        // [Current] + [Stored 2] + [Stored 1] + [Stored 0]
                        m_axis_tdata  <= {s_axis_tdata, stored_data};
                        m_axis_tvalid <= 1'b1;
                        
                        // 今回の入力にTLASTが付いていればLast、そうでなければLastではない
                        m_axis_tlast  <= s_axis_tlast;
                        
                        word_cnt      <= 2'd0; // カウンタリセット
                    end
                endcase
            end
        end
    end

endmodule
