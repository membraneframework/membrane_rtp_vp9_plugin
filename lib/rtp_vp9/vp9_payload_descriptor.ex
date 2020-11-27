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

  def parse_payload_descriptor(<<header::binary-size(1), rest::binary()>>) do
    {pid, rest} = get_pid(header, rest)
    {layer_indices, rest} = get_layer_indices(header, rest)
    {p_diffs, rest} = get_pdiffs(header, rest, 0)
    {ss, rest} = get_scalability_structure(header, rest)

    {header <> layer_indices <> p_diffs <> ss, rest}
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
         <<p_diff::binary-size(1), rest::binary>> = rest,
         diff_count
       )
       when diff_count < 3 do
    <<_::7, n::1>> = p_diff

    case n do
      1 ->
        {next_p_diff, rest} = get_pdiffs(header, rest, diff_count + 1)
        {p_diff <> next_p_diff, rest}

      _ ->
        {p_diff, rest}
    end
  end

  defp get_pdiffs(_, rest, _), do: {<<>>, rest}

  # no scalability structure
  defp get_scalability_structure(<<_iplfbe::6, 0::1, _z::1>>, rest), do: {<<>>, rest}

  defp get_scalability_structure(<<_iplfbe::6, 1::1, _z::1>>, rest) do
    <<ss_header::binary-size(1), rest::binary()>> = rest
    {widths_and_heights, rest} = ss_get_widths_heights(ss_header, rest, 0)
    {pg_descriptions, rest} = ss_get_pg_description(ss_header, rest)

    {ss_header <> widths_and_heights <> pg_descriptions, rest}
  end

  defp ss_get_widths_heights(<<n_s::3, 1::1, _g::1, _::3>> = ss_header, rest, count)
       when count <= n_s do
    <<width_height::binary-size(4), rest::binary()>> = rest
    {new_width_height, rest} = ss_get_widths_heights(ss_header, rest, count + 1)
    {width_height <> new_width_height, rest}
  end

  defp ss_get_widths_heights(_, rest, _), do: {<<>>, rest}

  defp ss_get_pg_description(<<_n_s::3, _y::1, 1::1, _::3>>, rest) do
    <<n_g_bin::binary-size(1), rest::binary()>> = rest
    <<n_g>> = n_g_bin
    {pg_descriptions, rest} =
    1..n_g
    |> Enum.reduce({<<>>, rest}, fn _i, {accumulated, rest} ->
      {pg_description, rest} = ss_get_pg_descriptions(rest)
      {accumulated <> pg_description, rest}
    end)

    {n_g_bin <> pg_descriptions, rest}
  end

  defp ss_get_pg_descriptions(<<first_octet::binary-size(1), rest::binary()>>) do
    <<_tid::3, _u::1, r::3, _::2>> = first_octet

    case r do
      0 ->
        {first_octet, rest}

      _ ->
        <<p_diffs::binary-size(r), rest::binary()>> = rest
        {first_octet <> p_diffs, rest}
    end
  end
end
