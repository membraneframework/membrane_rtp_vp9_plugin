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
      %PayloadDescriptor{first_octet: <<13>>} |> PayloadDescriptor.serialize()

    expected_output_payload = expected_payload_descriptor <> input_payload

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
               buffer:
                 {:output,
                  [
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
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

    begin_descriptor = %PayloadDescriptor{first_octet: <<9>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<1>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<5>>} |> PayloadDescriptor.serialize()

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

  test "failing buffers" do
    {input_payload, buffers} = File.read!("test/fixtures/buffers.txt") |> :erlang.binary_to_term()
    IO.inspect(byte_size(input_payload))
    input_buffer = %Buffer{payload: input_payload}

    begin_descriptor = %PayloadDescriptor{first_octet: <<9>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<1>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<5>>} |> PayloadDescriptor.serialize()

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{})

    {{:ok,
      [
        buffer:
          {:output,
           [
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<9, payload_1::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<1, payload_2::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<1, payload_3::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<1, payload_4::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: true}},
               payload: <<5, payload_5::binary()>>
             }
           ]},
        redemand: :output
      ]}, %State{}} = Payloader.handle_process(:input, input_buffer, nil, payloader_state)
    <<input_payload_1::binary-size(1207), input_payload_2::binary-size(1207), input_payload_3::binary-size(1207), input_payload_4::binary-size(1207), input_payload_5::binary-size(1205)>> = input_payload
    output_payload = payload_1 <> payload_2 <> payload_3 <> payload_4 <> payload_5
    assert byte_size(output_payload) == byte_size(input_payload)
    assert payload_1 == input_payload_1
    assert payload_2 == input_payload_2
    assert payload_3 == input_payload_3
    assert payload_4 == input_payload_4
    assert payload_5 == input_payload_5
  end

  test "two complete chunks one incomplete" do
    input_payload = <<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>
    input_buffer = %Buffer{payload: input_payload}

    begin_descriptor = %PayloadDescriptor{first_octet: <<9>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<1>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<5>>} |> PayloadDescriptor.serialize()

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
