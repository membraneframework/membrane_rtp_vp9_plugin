defmodule Membrane.RTP.VP9.Frame do
  @moduledoc """
  Module resposible for accumulating data from RTP packets into VP9 frames
  """
  alias Membrane.RTP.VP9.PayloadDescriptor
  alias Membrane.RTP.VP9.Depayloader

  @type t :: %__MODULE__{
          data: [binary()],
          last_seq_num: nil | Depayloader.sequence_number()
        }

  defguardp is_next(last_seq_num, next_seq_num) when rem(last_seq_num + 1, 65_536) == next_seq_num

  defstruct [:last_seq_num, data: []]

  @spec parse(binary(), Depayloader.sequence_number(), t()) ::
          {:ok, binary()}
          | {:error, :packet_malformed | :invalid_first_packet}
          | {:incomplete, t()}
  def parse(rtp_data, seq_num, acc) do
    with {:ok, {payload_descriptor, payload}} <-
           PayloadDescriptor.parse_payload_descriptor(rtp_data) do
      do_parse(payload_descriptor, payload, seq_num, acc)
    else
      _error -> {:error, :packet_malformed}
    end
  end

  @spec do_parse(PayloadDescriptor.t(), binary(), Depayloader.sequence_number(), t()) ::
          {:ok, binary()}
          | {:error, :invalid_first_packet}
          | {:incomplete, t()}
  defp do_parse(payload_descriptor, payload, seq_num, acc)

  # Parse packet that is beginning and the end of frame
  defp do_parse(
         %PayloadDescriptor{first_octet: <<_iplf::4, 1::1, 1::1, _vz::2>>},
         payload,
         _seq_num,
         nil
       ),
       do: {:ok, payload}

  # Parse first packet of frame, 4-th bit payload_descriptor first_octet (B-bit) is set
  defp do_parse(
         %PayloadDescriptor{first_octet: <<_iplf::4, 1::1, _evz::3>>},
         payload,
         seq_num,
         nil
       ),
       do: {:incomplete, %__MODULE__{data: [payload], last_seq_num: seq_num}}

  # Not the first packet of frame
  defp do_parse(
         %PayloadDescriptor{first_octet: <<_iplf::4, 0::1, _evz::3>>},
         _payload,
         _seq_num,
         %__MODULE__{last_seq_num: nil}
       ),
       do: {:error, :invalid_first_packet}

  # Last packet of frame
  defp do_parse(
         %PayloadDescriptor{first_octet: <<_iplf::4, 0::1, 1::1, _vz::2>>},
         payload,
         seq_num,
         %__MODULE__{data: acc, last_seq_num: last}
       )
       when is_next(last, seq_num) do
    accumulated_frame = [payload | acc] |> Enum.reverse() |> Enum.join()
    {:ok, accumulated_frame}
  end

  # packet in the middle (not first or last packet but with correct sequence number)
  defp do_parse(
         %PayloadDescriptor{first_octet: <<_iplf::4, 0::1, 0::1, _vz::2>>},
         payload,
         seq_num,
         %__MODULE__{data: acc, last_seq_num: last} = frame
       )
       when is_next(last, seq_num),
       do: {:incomplete, %__MODULE__{frame | data: [payload | acc], last_seq_num: seq_num}}

  defp do_parse(_payload_descriptor, _payload, _seq_num, _acc),
    do: {:error, :missing_packet}
end
