defmodule Membrane.RTP.VP9.PayloadDescriptorTest do
  use ExUnit.Case
  alias Membrane.RTP.VP9.PayloadDescriptor
  alias Membrane.RTP.VP9.PayloadDescriptor.{SSDimension, ScalabilityStructure, PGDescription}

  describe "VP9 Payload Descriptor parser" do
    test "payload too short" do
      payload = <<184>>
      assert {:error, :malformed_data} == PayloadDescriptor.parse_payload_descriptor(payload)
    end

    test "malformed single byte picture id" do
      payload = <<128, 4::3>>
      assert {:error, :malformed_data} == PayloadDescriptor.parse_payload_descriptor(payload)
    end

    test "malformed double byte picture id" do
      payload = <<128, 128, 4::3>>
      assert {:error, :malformed_data} == PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|1|0|1|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |0|1 0 1 0 1 0 1| (PICTURE ID)
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| (P_DIFF 1)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1|        (P_DIFF 2)
        +-+-+-+-+-+
    """
    test "malformed pdiffs" do
      payload = <<216, 85, 85, 21::5>>
      assert {:error, :malformed_data} == PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|0|1|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|1|0|0|0| (FIRST OCTET OF SS)
        +-+-+-+-+-+-+-+-+
        |0 0 0 0 0 0 1 0| (N_G)
        +-+-+-+-+-+-+-+-+
        |0 0 0|0|1 0|0 0| (TID | U | R | _ _ )
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (P_DIFF 1) Note that R=2 but there is only one P_DIFF
        +-+-+-+-+-+-+-+-+
        |0 0 1|1|0 1|0 0| (TID | U | R | _ _ )
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| (P_DIFF 1)
        +-+-+-+-+-+-+-+-+
    """
    test "malformed pg descriptions SS too short" do
      payload = <<2, 8, 2, 8, 170, 52>>
      assert {:error, :malformed_data} == PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|0|1|1|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
    I:  |0|1 0 1 1 0 1 1| (PICTURE ID)
        +-+-+-+-+-+-+-+-+
    L:  |0 0 1|1|0 1 0|0| (TID | U | SID | D)
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with picture id and layer indices" do
      payload = <<184, 91, 52, 233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: <<184>>,
        picture_id: 91,
        tid: 1,
        u: 1,
        d: 0,
        sid: 2
      }

      expected_rest = <<233, 29, 109, 237>>

      assert {:ok, {actual_descriptor, rest}} =
               PayloadDescriptor.parse_payload_descriptor(payload)

      assert expected_descriptor == actual_descriptor
      assert expected_rest == rest
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|1|1|1|0|0|0| (FIRST OCTET) Note: I = 0 and F = 1 which is not allowed
        +-+-+-+-+-+-+-+-+
    I:  |1|1 0 1 1 0 1 1| (EXTENDED PICTURE ID)
        |1 1 1 1 1 1 1 1|
        +-+-+-+-+-+-+-+-+
    L:  |0 0 1|1|0 1 0|0| (TID | U | SID | D)
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| TL0PICIDX
        +-+-+-+-+-+-+-+-+
    """
    test "descriptor with I equal to 0 and F equal to 1" do
      payload = <<56, 219, 255, 52, 85, 233, 29, 109, 237>>

      assert {:error, :malformed_data} == PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|0|1|1|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
    I:  |1|1 0 1 1 0 1 1| (EXTENDED PICTURE ID)
        |1 1 1 1 1 1 1 1|
        +-+-+-+-+-+-+-+-+
    L:  |0 0 1|1|0 1 0|0| (TID | U | SID | D)
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with extended picture id, layer indices" do
      payload = <<184, 219, 255, 52, 233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: <<184>>,
        picture_id: 56_319,
        tid: 1,
        u: 1,
        d: 0,
        sid: 2
      }

      expected_rest = <<233, 29, 109, 237>>

      assert {:ok, {actual_descriptor, rest}} =
               PayloadDescriptor.parse_payload_descriptor(payload)

      assert expected_descriptor == actual_descriptor
      assert expected_rest == rest
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|1|0|1|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |0|1 0 1 0 1 0 1| (PICTURE ID)
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| (P_DIFF 1)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (P_DIFF 2)
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with picture id and two p_diffs" do
      payload = <<216, 85, 85, 170, 233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: <<216>>,
        picture_id: 85,
        tid: nil,
        u: nil,
        d: nil,
        sid: nil,
        p_diffs: [85, 170],
        tl0picidx: nil,
        scalability_structure: nil
      }

      expected_rest = <<233, 29, 109, 237>>

      assert {:ok, {actual_descriptor, rest}} =
               PayloadDescriptor.parse_payload_descriptor(payload)

      assert expected_descriptor == actual_descriptor
      assert expected_rest == rest
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|1|0|1|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |0|0|1|1|0|0|0|0| (FIRST OCTET OF SS |N_S|Y|G|---|) -> N_S = 1
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| (WIDTH 1)       -\
        |0 1 0 1 0 1 0 1|                 .
        +-+-+-+-+-+-+-+-+                 .
        |0 1 0 1 0 1 0 1| (HEIGHT 1)      .
        |0 1 0 1 0 1 0 1|                 .
        +-+-+-+-+-+-+-+-+                 . - N_S+1 = 2 times
        |0 1 0 1 0 1 0 1| (WIDTH 2)       .
        |0 1 0 1 0 1 0 1|                 .
        +-+-+-+-+-+-+-+-+                 .
        |0 1 0 1 0 1 0 1| (HEIGHT 2)      .
        |0 1 0 1 0 1 0 1|                 -/
        +-+-+-+-+-+-+-+-+

    """

    test "descriptor with only scalability structure" do
      payload = <<10, 48, 85, 85, 85, 85, 85, 85, 85, 85, 233, 29, 109, 237>>

      expected_ss = %ScalabilityStructure{
        first_octet: 48,
        dimensions: [
          %SSDimension{width: 21_845, height: 21_845},
          %SSDimension{width: 21_845, height: 21_845}
        ]
      }

      expected_descriptor = %PayloadDescriptor{
        first_octet: <<10>>,
        scalability_structure: expected_ss
      }

      expected_rest = <<233, 29, 109, 237>>

      assert {:ok, {actual_descriptor, rest}} =
               PayloadDescriptor.parse_payload_descriptor(payload)

      assert expected_descriptor == actual_descriptor
      assert expected_rest == rest
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|0|1|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|1|0|0|0| (FIRST OCTET OF SS)
        +-+-+-+-+-+-+-+-+
        |0 0 0|0|1 0|0 0| (TID | U | R | _ _ )
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (P_DIFF 1)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (P_DIFF 2)
        +-+-+-+-+-+-+-+-+
        |0 0 1|1|0 1|0 0| (TID | U | R | _ _ )
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| (P_DIFF 1)
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with scalability structure and p_diffs" do
      payload = <<2, 8, 2, 8, 170, 170, 52, 85, 233, 29, 109, 237>>

      expected_ss = %ScalabilityStructure{
        first_octet: 8,
        pg_descriptions: [
          %PGDescription{
            tid: 0,
            u: 0,
            p_diffs: [170, 170]
          },
          %PGDescription{
            tid: 1,
            u: 1,
            p_diffs: [85]
          }
        ]
      }

      expected_rest = <<233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: <<2>>,
        scalability_structure: expected_ss
      }

      assert {:ok, {actual_descriptor, rest}} =
               PayloadDescriptor.parse_payload_descriptor(payload)

      assert expected_descriptor == actual_descriptor
      assert expected_rest == rest
    end
  end
end
