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
                      metadata: %{rtp: %{marker: true}},
                      payload: expected_output_payload
                    }
                  ]},
               redemand: :output
             ]},
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end

  test "three complete chunks" do
    input_payload = <<1, 2, 3, 4, 5, 6, 7, 8, 9>>
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
                      payload: begin_descriptor <> <<1, 2, 3>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: middle_descriptor <> <<4, 5, 6>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
                      payload: end_descriptor <> <<7, 8, 9>>
                    }
                  ]},
               redemand: :output
             ]},
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end

  test "keyframe buffer" do
    {input_payload, buffers} =
      File.read!("test/fixtures/keyframe_buffer.dump") |> :erlang.binary_to_term()

    input_buffer = %Buffer{payload: input_payload}

    begin_descriptor = %PayloadDescriptor{first_octet: <<8>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<0>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<4>>} |> PayloadDescriptor.serialize()

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{})

    {{:ok,
      [
        buffer:
          {:output,
           [
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<8, payload_1::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<0, payload_2::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<0, payload_3::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: false}},
               payload: <<0, payload_4::binary()>>
             },
             %Buffer{
               metadata: %{rtp: %{marker: true}},
               payload: <<4, payload_5::binary()>>
             }
           ]},
        redemand: :output
      ]}, %State{}} = Payloader.handle_process(:input, input_buffer, nil, payloader_state)

    <<input_payload_1::binary-size(1207), input_payload_2::binary-size(1207),
      input_payload_3::binary-size(1207), input_payload_4::binary-size(1207),
      input_payload_5::binary-size(1205)>> = input_payload

    output_payload = payload_1 <> payload_2 <> payload_3 <> payload_4 <> payload_5
    assert byte_size(output_payload) == byte_size(input_payload)
    assert payload_1 == input_payload_1
    assert payload_2 == input_payload_2
    assert payload_3 == input_payload_3
    assert payload_4 == input_payload_4
    assert payload_5 == input_payload_5
  end

  test "two complete chunks one incomplete" do
    input_payload = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11>>
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
                      payload: begin_descriptor <> <<1, 2, 3>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: middle_descriptor <> <<4, 5, 6>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload: middle_descriptor <> <<7, 8, 9>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
                      payload: end_descriptor <> <<10, 11>>
                    }
                  ]},
               redemand: :output
             ]},
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end
end
