defmodule Membrane.RTP.VP9.Payloader do
  @moduledoc """
  Payloads VP9 frames into RTP payloads while adding payload descriptors.

  Based on https://tools.ietf.org/html/draft-ietf-payload-vp9-10

  """

  use Membrane.Filter

  alias Membrane.Caps.VP9
  alias Membrane.{Buffer, RemoteStream, RTP}
  alias Membrane.RTP.VP9.PayloadDescriptor

  def_options max_payload_size: [
                spec: non_neg_integer(),
                default: 1370,
                description: """
                Maximal size of outputted payloads in bytes. RTP packet will contain VP9 payload descriptor which can have around 30B.
                The resulting RTP packet will also RTP header (min 12B). After adding UDP header (8B), IPv4 header(min 20B, max 60B)
                everything should fit in standard MTU size (1500B)
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
  def handle_process(
        :input,
        %Buffer{metadata: metadata, payload: payload},
        _ctx,
        state
      ) do
    chunk_count = ceil(byte_size(payload) / state.max_payload_size)
    max_chunk_size = ceil(byte_size(payload) / chunk_count)

    {buffers, _i} =
      payload
      |> Bunch.Binary.chunk_every_rem(max_chunk_size)
      |> add_descriptors()
      |> Enum.map_reduce(1, fn chunk, i ->
        {%Buffer{
           metadata: Bunch.Struct.put_in(metadata, [:rtp], %{marker: i == chunk_count}),
           payload: chunk
         }, i + 1}
      end)

    {{:ok, [buffer: {:output, buffers}, redemand: :output]}, state}
  end

  defp add_descriptors({[], chunk}) do
    begin_end_descriptor =
      %PayloadDescriptor{first_octet: <<13>>} |> PayloadDescriptor.serialize()

    [begin_end_descriptor <> chunk]
  end

  defp add_descriptors({[chunk], <<>>}) do
    begin_end_descriptor =
      %PayloadDescriptor{first_octet: <<13>>} |> PayloadDescriptor.serialize()

    [begin_end_descriptor <> chunk]
  end

  defp add_descriptors({chunks, <<>>}) do
    begin_descriptor = %PayloadDescriptor{first_octet: <<9>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<1>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<5>>} |> PayloadDescriptor.serialize()
    chunks_count = length(chunks)

    {chunks, _i} =
      chunks
      |> Enum.map_reduce(1, fn element, i ->
        case i do
          1 ->
            {begin_descriptor <> element, i + 1}

          ^chunks_count ->
            {end_descriptor <> element, i + 1}

          _middle ->
            {middle_descriptor <> element, i + 1}
        end
      end)

    chunks
  end

  defp add_descriptors({chunks, last_chunk}) do
    begin_descriptor = %PayloadDescriptor{first_octet: <<9>>} |> PayloadDescriptor.serialize()
    middle_descriptor = %PayloadDescriptor{first_octet: <<1>>} |> PayloadDescriptor.serialize()
    end_descriptor = %PayloadDescriptor{first_octet: <<5>>} |> PayloadDescriptor.serialize()

    [first_chunk | chunks] = chunks

    chunks =
      chunks
      |> Enum.reduce([end_descriptor <> last_chunk], fn chunk, acc ->
        [middle_descriptor <> chunk | acc]
      end)

    [begin_descriptor <> first_chunk | chunks]
  end
end
