defmodule Membrane.RTP.VP9.PayloaderTest do
  use ExUnit.Case
  alias Membrane.RTP.VP9.Payloader
  alias Membrane.RTP.VP9.Payloader.State
  alias Membrane.RTP.VP9.PayloadDescriptor

  alias Membrane.Buffer

  test "fragmentation not required" do
    input_payload = <<1, 1, 1>>
    input_buffer = %Buffer{payload: input_payload}

    expected_payload_descriptor =
      %PayloadDescriptor{first_octet: <<12>>} |> PayloadDescriptor.serialize()

    expected_output_payload = expected_payload_descriptor <> input_payload

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
               buffer:
                 {:output,
                  [
                    %Buffer{
                      metadata: %{},
                      payload: expected_output_payload
                    }
                  ]},
               redemand: :output
             ]},
            %State{max_payload_size: 3}} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end

  test "three complete chunks" do
    input_payload = <<1, 1, 1, 1, 1, 1, 1, 1, 1>>
    input_buffer = %Buffer{payload: input_payload}

    begin_descriptor = %PayloadDescriptor{first_octet: <<8>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<0>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<4>>} |> PayloadDescriptor.serialize()

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
               buffer:
                 {:output,
                  [
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: begin_descriptor <> <<1, 1, 1>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: middle_descriptor <> <<1, 1, 1>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
                      payload: end_descriptor <> <<1, 1, 1>>
                    }
                  ]},
               redemand: :output
             ]},
            %State{max_payload_size: 3}} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end

  test "two complete chunks one incomplete" do
    input_payload = <<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>
    input_buffer = %Buffer{payload: input_payload}

    begin_descriptor = %PayloadDescriptor{first_octet: <<8>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<0>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<4>>} |> PayloadDescriptor.serialize()

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
               buffer:
                 {:output,
                  [
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: begin_descriptor <> << 1, 1, 1>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: middle_descriptor <> <<1, 1, 1>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: middle_descriptor <> <<1, 1, 1>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
                      payload: end_descriptor <> <<1, 1>>
                    }
                  ]},
               redemand: :output
             ]},
            %State{max_payload_size: 3}} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end
end
