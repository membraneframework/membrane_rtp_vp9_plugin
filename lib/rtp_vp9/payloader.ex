defmodule Membrane.RTP.VP9.Payloader do
  @moduledoc """
  Payloads VP9 frames into RTP payloads while adding payload descriptors.

  Based on https://tools.ietf.org/html/draft-ietf-payload-vp9-10

  """

  use Membrane.Filter

  alias Membrane.{Buffer, RemoteStream, RTP}

  @max_payload_size 1459

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

  @impl true
  def handle_init(_options), do: {:ok, %{}}

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    caps = RTP
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(
        :input,
        buffer,
        _ctx,
        _state
      ) do
    {{:ok, [buffer: split_into_buffers(buffer), redemand: :output]}, %{}}
  end

  defp split_into_buffers(buffer) do
    %Buffer{payload: payload} = buffer

    chunks_count = ceil(byte_size(payload) / @max_payload_size)
    1..chunks_count
    |> Enum.map_reduce(payload, fn _i, acc ->
      with <<chunk::binary-size(@max_payload_size), rest::binary()>> <- acc do
        {%Buffer{buffer | payload: chunk}, rest}
      else
        _error -> {%Buffer{buffer | payload: acc}, <<>>}
      end
    end)
  end
end
