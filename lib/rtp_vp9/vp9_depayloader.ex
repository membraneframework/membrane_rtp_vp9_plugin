defmodule Membrane.RTP.VP9.Depayloader do
  @moduledoc """
  Depayloads VP9 RTP payloads into VP9 frames.

  Based on https://tools.ietf.org/html/draft-ietf-payload-vp9-10
  """

  use Membrane.Filter
  use Membrane.Log

  alias Membrane.RTP
  alias Membrane.RTP.VP9.Frame
  alias Membrane.Caps.VP9
  alias Membrane.Buffer
  alias Membrane.Event.Discontinuity

  @type sequence_number :: 0..65_535

  def_output_pad :output, caps: {VP9, []}

  def_input_pad :input, caps: {RTP, []}, demand_unit: :buffers

  defmodule State do
    @moduledoc false
    defstruct frame_acc: nil
  end

  @impl true
  def handle_init(_options) do
    {:ok, %State{}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(
        :input,
        buffer,
        _ctx,
        state
      ) do
    with {{:ok, actions}, new_state} <- parse_buffer(buffer, state) do
      {{:ok, actions ++ [redemand: :output]}, new_state}
    else
      {:error, reason} ->
        log_malformed_buffer(buffer, reason)
        {{:ok, redemand: :output}, %State{state | frame_acc: nil}}
    end
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_event(:input, %Discontinuity{} = event, _ctx, state),
    do: {{:ok, forward: event}, %State{state | frame_acc: nil}}

  defp parse_buffer(
         %Buffer{payload: payload, metadata: %{rtp: %{sequence_number: seq_num}}} = buffer,
         state
       ) do
    case Frame.parse(payload, seq_num, state.frame_acc) do
      {:ok, vp9_frame} ->
        {{:ok, [buffer: {:output, %{buffer | payload: vp9_frame}}]},
         %State{state | frame_acc: nil}}

      {:incomplete, frame_acc} ->
        {{:ok, []}, %State{state | frame_acc: frame_acc}}

      {:error, _} = error ->
        error
    end
  end

  defp log_malformed_buffer(packet, reason) do
    warn("""
    An error occurred while parsing RTP packet.
    Reason: #{reason}
    Packet: #{inspect(packet, limit: :infinity)}
    """)
  end
end
