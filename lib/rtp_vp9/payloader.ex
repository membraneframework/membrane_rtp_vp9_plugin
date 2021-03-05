defmodule Membrane.RTP.VP9.Payloader do
  @moduledoc """
  Payloads VP9 frames into RTP payloads while adding payload descriptors.

  Based on https://tools.ietf.org/html/draft-ietf-payload-vp9-10

  """

  use Membrane.Filter

  alias Membrane.Caps.VP9
  alias Membrane.{Buffer, RemoteStream, RTP}

  # predefines simple payload descriptors for RTP packages after fragmentation
  @first_fragment_descriptor <<8>>
  @middle_fragment_descriptor <<0>>
  @last_fragment_descriptor <<4>>
  @single_fragment_frame_descriptor <<12>>

  def_options max_payload_size: [
                spec: non_neg_integer(),
                default: 1370,
                description: """
                Maximal size of outputted payloads in bytes. RTP packet will contain VP9 payload descriptor which can have around 30B.
                The resulting RTP packet will also RTP header (min 12B). After adding UDP header (8B), IPv4 header(min 20B, max 60B)
                everything should fit in standard MTU size (1500B)
                """
              ],
              payload_descriptor_type: [
                spec: :simple,
                default: :simple,
                description: """
                When set to :simple payloader will generate only minimal payload descriptors required for fragmentation.
                More complex payload descriptors are not yet supported so this option should be left as default.
                """
              ]

  def_output_pad :output, caps: RTP

  def_input_pad :input,
    caps: {RemoteStream, content_format: VP9, type: :packetized},
    demand_unit: :buffers

  defmodule State do
    @moduledoc false
    defstruct [
      :max_payload_size
    ]
  end

  @impl true
  def handle_init(options), do: {:ok, Map.merge(%State{}, Map.from_struct(options))}

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, %RTP{}}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    %Buffer{metadata: metadata, payload: payload} = buffer
    chunk_count = ceil(byte_size(payload) / state.max_payload_size)
    max_chunk_size = ceil(byte_size(payload) / chunk_count)

    buffers =
      payload
      |> Bunch.Binary.chunk_every_rem(max_chunk_size)
      |> add_descriptors()
      |> Enum.map(
        &%Buffer{
          metadata: Bunch.Struct.put_in(metadata, [:rtp], %{marker: false}),
          payload: &1
        }
      )
      |> List.update_at(-1, &Bunch.Struct.put_in(&1, [:metadata, :rtp, :marker], true))

    {{:ok, [buffer: {:output, buffers}, redemand: :output]}, state}
  end

  defp add_descriptors({[chunk], <<>>}), do: [@single_fragment_frame_descriptor <> chunk]

  defp add_descriptors({chunks, last_chunk}) do
    chunks = if byte_size(last_chunk) > 0, do: chunks ++ [last_chunk], else: chunks
    chunks_count = length(chunks)

    chunks
    |> Enum.map_reduce(
      1,
      fn element, i ->
        case i do
          1 ->
            {@first_fragment_descriptor <> element, i + 1}

          ^chunks_count ->
            {@last_fragment_descriptor <> element, i + 1}

          _middle ->
            {@middle_fragment_descriptor <> element, i + 1}
        end
      end
    )
    |> elem(0)
  end
end
