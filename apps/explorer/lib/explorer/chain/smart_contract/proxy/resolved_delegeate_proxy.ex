defmodule Explorer.Chain.SmartContract.Proxy.ResolvedDelegateProxy do
  @moduledoc """
  Module for fetching proxy implementation from ResolvedDelegateProxy https://github.com/ethereum-optimism/optimism/blob/9580179013a04b15e6213ae8aa8d43c3f559ed9a/packages/contracts-bedrock/src/legacy/ResolvedDelegateProxy.sol
  """
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  # 8da5cb5b = keccak256(owner())
  @owner_signature "8da5cb5b"

  # 204e1c7a = keccak256(getProxyImplementation(address))
  @get_proxy_implementation_signature "204e1c7a"

  @owner_method_abi [
    %{
      "inputs" => [],
      "name" => "owner",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @get_proxy_implementation_method_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "address",
          "name" => "_proxy",
          "type" => "address"
        }
      ],
      "name" => "getProxyImplementation",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @doc """
  Get implementation address hash string following ResolvedDelegateProxy proxy pattern
  """
  @spec get_implementation_address_hash_string(Hash.Address.t()) :: nil | :error | binary
  def get_implementation_address_hash_string(proxy_address_hash) do
    address_manager_hash = get_address_manager_from_proxy(proxy_address_hash)
    owner_address_hash = get_owner_from_address_manager(address_manager_hash)
    get_implementation_from_owner(owner_address_hash, proxy_address_hash)
  end

  defp get_address_manager_from_proxy(_proxy_address_hash) do
    # todo get address manager from constructor arguments
  end

  defp get_owner_from_address_manager(address_manager_hash) do
    case @owner_signature
         |> SmartContractHelper.get_binary_string_from_contract_getter(
           to_string(address_manager_hash),
           @owner_method_abi
         ) do
      <<owner_address_hash::binary-size(42)>> ->
        owner_address_hash

      other_result ->
        other_result
    end
  end

  defp get_implementation_from_owner(owner_hash, proxy_address_hash_string) do
    {:ok, proxy_address_hash} =
      proxy_address_hash_string
      |> to_string()
      |> Chain.string_to_address_hash()

    padded_proxy_address_hash_string =
      proxy_address_hash
      |> Chain.hash_to_iodata()
      |> IO.iodata_to_binary()

    signature = @get_proxy_implementation_signature <> padded_proxy_address_hash_string

    case signature
         |> SmartContractHelper.get_binary_string_from_contract_getter(
           to_string(owner_hash),
           @get_proxy_implementation_method_abi
         ) do
      <<implementation_address_hash::binary-size(42)>> ->
        implementation_address_hash

      other_result ->
        other_result
    end
  end
end
