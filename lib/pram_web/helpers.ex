defmodule PramWeb.Helpers do
  @moduledoc """
  Helper functions for the PramWeb application.
  """

  @doc """
  Returns a string of the changeset errors.
  """
  @spec changeset_errors(Ecto.Changeset.t()) :: String.t()
  def changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {key, msg} -> "#{key}: #{msg}" end)
  end
end
