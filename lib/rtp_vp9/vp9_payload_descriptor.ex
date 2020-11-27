defmodule Membrane.RTP.VP9.PayloadDescriptor do
  @moduledoc """
  Defines a structure representing VP9 payload descriptor
  Described here: https://tools.ietf.org/html/draft-ietf-payload-vp9-10#section-4.2

  Flexible mode:
  ```
         0 1 2 3 4 5 6 7
        +-+-+-+-+-+-+-+-+
        |I|P|L|F|B|E|V|Z| (REQUIRED)
        +-+-+-+-+-+-+-+-+
   I:   |M| PICTURE ID  | (REQUIRED)
        +-+-+-+-+-+-+-+-+
   M:   | EXTENDED PID  | (RECOMMENDED)
        +-+-+-+-+-+-+-+-+
   L:   | TID |U| SID |D| (CONDITIONALLY RECOMMENDED)
        +-+-+-+-+-+-+-+-+                             -\
   P,F: | P_DIFF      |N| (CONDITIONALLY REQUIRED)    - up to 3 times
        +-+-+-+-+-+-+-+-+                             -/
   V:   | SS            |
        | ..            |
        +-+-+-+-+-+-+-+-+
  ```
  Non-flexible mode:
  ```
         0 1 2 3 4 5 6 7
        +-+-+-+-+-+-+-+-+
        |I|P|L|F|B|E|V|Z| (REQUIRED)
        +-+-+-+-+-+-+-+-+
   I:   |M| PICTURE ID  | (RECOMMENDED)
        +-+-+-+-+-+-+-+-+
   M:   | EXTENDED PID  | (RECOMMENDED)
        +-+-+-+-+-+-+-+-+
   L:   | TID |U| SID |D| (CONDITIONALLY RECOMMENDED)
        +-+-+-+-+-+-+-+-+
        |   TL0PICIDX   | (CONDITIONALLY REQUIRED)
        +-+-+-+-+-+-+-+-+
   V:   | SS            |
        | ..            |
        +-+-+-+-+-+-+-+-+
  ```
  """

  #   @spec parse_payload_descriptor(binary()) :: {:error, :malformed_data} | {:ok, {t(), binary()}}
  def parse_payload_descriptor(raw_payload)

  def parse_payload_descriptor(<<header, rest::binary()>>) do
    {:error}
  end

  # no picture id (PID)
  defp get_pid(<<0::1, _::7>>, rest), do: {<<>>, rest}

  # picture id (PID) present
  defp get_pid(<<1::1, _::7>>, <<pid::binary-size(1), rest::binary>> = rest) do
    case pid do
      <<0::1, _rest_of_pid::7>> ->
        {pid, rest}

      <<1::1, _rest_of_pid::7>> ->
        <<second_byte::binary-size(1), rest::binary()>> = rest
        {pid <> second_byte, rest}

      _ ->
        :error
    end
  end

  # no layer indices
  defp get_layer_indices(<<_i::1, _p::1, 0::1, _::6>> = header, rest), do: {<<>>, rest}

  # layer indices present
  defp get_layer_indices(<<_i::1, _p::1, 1::1, f::1, _::5>> = header, rest) do
    case f do
      # TL0PICIDX present
      0 ->
        <<ids_and_tl0picidx::binary-size(2), rest::binary()>> = rest
        {ids_and_tl0picidx, rest}

      # no TL0PICIDX
      _ ->
        <<ids::binary-size(1), rest::binary()>> = rest
        {ids, rest}
    end
  end

  defp get_pdiffs(
         <<_i::1, 1::1, _l::1, 1::1, _::4>> = header,
         <<p_diff::binary-size(7), n::1, rest::binary>> = rest,
         diff_count
       )
       when diff_count < 3 do
    case n do
      1 ->
        p_diff <> get_pdiffs(header, rest, diff_count + 1)

      _ ->
        p_diff
    end
  end

  defp get_pdiffs(_,_,_), do: <<>>
end
