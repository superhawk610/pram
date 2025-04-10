defmodule PramWeb.Helpers do
  @moduledoc """
  Helper functions for the PramWeb application.
  """

  @doc """
  Returns a string of the changeset errors, handling nested error structures.
  """
  @spec changeset_errors(Ecto.Changeset.t()) :: String.t()
  def changeset_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    format_errors(errors)
  end

  @doc """
  Converts a changeset to a map containing only changed fields.
  Useful for keeping URLs clean by only including modified parameters.
  """
  @spec to_params_changed_only(Ecto.Changeset.t()) :: map()
  def to_params_changed_only(%Ecto.Changeset{changes: changes}) do
    Map.new(changes, fn
      {key, changeset = %Ecto.Changeset{}} -> {key, to_params_changed_only(changeset)}
      {key, value} -> {key, value}
    end)
  end

  @doc """
  Converts a struct or value to a format suitable for URL parameters.
  Handles dates, structs, and nested structures.
  """
  @spec to_params(term()) :: term()
  def to_params(%Date{} = date), do: Date.to_iso8601(date)

  def to_params(%_{} = params) do
    params
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {key, to_params(value)} end)
  end

  def to_params(v), do: v

  @doc """
  Formats an error message for invalid parameters.
  Returns a generic message if no specific errors, or a detailed message with the errors.
  """
  @spec format_invalid_param_message(Ecto.Changeset.t()) :: String.t()
  def format_invalid_param_message(changeset) do
    case changeset_errors(changeset) do
      "" -> "Invalid query parameters removed"
      errors -> "Invalid query parameters: #{errors}"
    end
  end

  @doc """
  Handles the result of a changeset validation, returning either:
  - {:ok, params} with only the changed parameters for valid changesets
  - {:error, changeset} for invalid changesets
  """
  @spec handle_changeset_result(Ecto.Changeset.t()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def handle_changeset_result(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = valid_changeset ->
        params = to_params_changed_only(valid_changeset)
        {:ok, params}

      invalid_changeset ->
        {:error, invalid_changeset}
    end
  end

  # Format errors recursively, handling both maps and lists
  defp format_errors(errors) when is_map(errors) do
    errors
    |> Enum.map(fn {key, value} ->
      formatted_value = format_errors(value)
      "#{key} #{formatted_value}"
    end)
    |> Enum.join(", ")
  end

  defp format_errors(errors) when is_list(errors) do
    errors |> Enum.join(", ")
  end

  defp format_errors(error), do: to_string(error)
end
