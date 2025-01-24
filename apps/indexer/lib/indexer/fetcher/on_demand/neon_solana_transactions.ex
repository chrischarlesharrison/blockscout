defmodule Indexer.Fetcher.OnDemand.NeonSolanaTransactions do
  @moduledoc """
  A Caching proxy service getting linked solana transactions from NeonEVM Node.
  The corresponding node data is available only via a dedicated endpoint
  so we don't fetch those unless a user explicitly requests so to minimize requests.
  """
  require Logger

  import Ecto.Query, only: [from: 2]
  alias Explorer.Chain.Neon.LinkedSolanaTransactions
  alias Explorer.Repo

  def trigger_fetch(transaction_hash,decoded_transaction_hash) do
    arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)
    case EthereumJSONRPC.get_linked_solana_transactions(transaction_hash, arguments) do
      # and Enum.all?(linked_transactions, &is_binary/1)
      {:ok, fetched} when is_list(fetched)->
        cache(decoded_transaction_hash, fetched)
        {:ok, fetched}
      {:ok, bad_response} ->
        Logger.warning("Got bad response from NeonEVM Node: #{bad_response}")
        {:error, "Invalid response from node"}
      {:error, reason} -> {:error, "Unable to fetch data from the node: #{inspect(reason)}"}
    end
  end

  def query_from_db(decoded_transaction_hash) do
   Repo.all(from(
      solanaTransaction in LinkedSolanaTransactions,
      where: solanaTransaction.neon_transaction_hash == ^decoded_transaction_hash,
      select: solanaTransaction.solana_transaction_hash
    ))
  end

  defp cache(decoded_transaction_hash, fetched) do
    entries =
      Enum.map(fetched, fn sol_transaction_hash_string ->
        %{
          neon_transaction_hash: decoded_transaction_hash,
          solana_transaction_hash: sol_transaction_hash_string,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    Repo.transaction(fn ->
      Repo.insert_all(
        LinkedSolanaTransactions,
        entries,
        on_conflict: :nothing, # Ignore duplicates
        conflict_target: [:neon_transaction_hash, :solana_transaction_hash]
      )
    end)
  end



  @spec maybe_fetch(EthereumJSONRPC.hash()) :: {:ok, list} | {:error, String.t()}
  def maybe_fetch(transaction_hash) do
    transaction_hash = normalize(transaction_hash)

    case Base.decode16(transaction_hash, case: :lower) do
      {:ok, decoded_transaction_hash} ->
        case query_from_db(decoded_transaction_hash) do
          {:ok, results} when results != [] ->
            {:ok, results}

          [] ->
            trigger_fetch(transaction_hash,decoded_transaction_hash)

          {:error, reason} ->
            {:error, "Failed to query linked transactions: #{inspect(reason)}"}
        end
    end
  end

  defp normalize(hex_string) do
    case hex_string do
      "0x" <> rest -> rest
      hex -> hex
    end
  end
end
