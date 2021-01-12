defmodule Membrane.RTP.VP9.DepayloaderTest do
  use ExUnit.Case
  alias Membrane.RTP.VP9.Depayloader
  alias Membrane.RTP.VP9.Depayloader.State
  alias Membrane.Buffer

  @doc """
  Two RTP buffers that adds up to one VP9 frame

  1:
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP9 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+
  2:
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|1|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 1 0 0| (VP9 PAYLOAD)
        |1 0 1 0 1 1 0 1|
        +-+-+-+-+-+-+-+-+
  """
  test "two rtp buffers carrying one vp9 frame" do
    buffer_1 = %Buffer{payload: <<8, 170, 171>>, metadata: %{rtp: %{sequence_number: 14_450}}}
    buffer_2 = %Buffer{payload: <<4, 172, 173>>, metadata: %{rtp: %{sequence_number: 14_451}}}
    {:ok, depayloader_state} = Depayloader.handle_init([])

    assert {{:ok, [redemand: :output]}, depayloader_state} =
             Depayloader.handle_process(:input, buffer_1, nil, depayloader_state)

    assert {{:ok,
             [
               buffer:
                 {:output,
                  %Buffer{
                    metadata: %{rtp: %{sequence_number: 14_451}},
                    payload: <<170, 171, 172, 173>>
                  }},
               redemand: :output
             ]},
            %State{frame_acc: nil}} =
             Depayloader.handle_process(:input, buffer_2, nil, depayloader_state)
  end

  @doc """
    one rtp buffer carrying one vp9 frame
    1:
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|1|1|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP9 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+
  """
  test "one rtp buffer carrying one vp9 frame" do
    buffer = %Buffer{payload: <<12, 170, 171>>, metadata: %{rtp: %{sequence_number: 14_450}}}
    {:ok, depayloader_state} = Depayloader.handle_init([])

    assert {{:ok,
             [
               buffer:
                 {:output,
                  %Buffer{
                    metadata: %{rtp: %{sequence_number: 14_450}},
                    payload: <<170, 171>>
                  }},
               redemand: :output
             ]},
            %State{frame_acc: nil}} =
             Depayloader.handle_process(:input, buffer, nil, depayloader_state)
  end

  @doc """
    missing packet,

  sequence number 14450:
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP9 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+

  sequence number 14452:
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|1|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 1 0 0| (VP9 PAYLOAD)
        |1 0 1 0 1 1 0 1|
        +-+-+-+-+-+-+-+-+
  """
  test "missing packet" do
    buffer_1 = %Buffer{payload: <<8, 170, 171>>, metadata: %{rtp: %{sequence_number: 14_450}}}
    buffer_2 = %Buffer{payload: <<4, 172, 173>>, metadata: %{rtp: %{sequence_number: 14_452}}}
    {:ok, depayloader_state} = Depayloader.handle_init([])

    assert {{:ok, [redemand: :output]}, depayloader_state} =
             Depayloader.handle_process(:input, buffer_1, nil, depayloader_state)

    assert {{:ok, redemand: :output}, %State{frame_acc: nil}} =
             Depayloader.handle_process(:input, buffer_2, nil, depayloader_state)
  end
end
