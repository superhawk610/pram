defmodule PramWeb.PramLive.Index do
  use PramWeb, :live_view

  alias Ecto.Changeset
  alias PramWeb.Helpers

  # Parameter handling in Phoenix LiveView follows a specific pattern:
  # 1. Define schemas to validate and structure parameters
  # 2. Only include non-default values in URLs (keep URLs clean)
  # 3. Handle parameter changes consistently through handle_params
  # 4. Provide clear feedback when parameters are invalid

  # The Favorites schema demonstrates parameter handling for nested structures
  defmodule Favorites do
    use Ecto.Schema
    import Ecto.Changeset

    # Using embedded_schema to define the structure and types for parameter casting and validation
    embedded_schema do
      # Default values reduce URL clutter - only non-default values appear in URL
      field :flavor, :string, default: "vanilla"
      field :topping, :string, default: "sprinkles"
      field :servings, :integer, default: 1
    end

    def changeset(model, params) do
      model
      |> cast(params, [:flavor, :topping, :servings])
    end
  end

  # Main parameter schema showing how to handle complex parameter structures
  defmodule Params do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      # Basic parameter fields
      field :name, :string
      field :email, :string

      # Nested parameter structures using embeds_one
      # on_replace: :update ensures proper handling of nested parameter updates
      embeds_one :date_filter, DateFilter, on_replace: :update do
        field :start_date, :date, default: ~D[2025-01-01]
        field :end_date, :date
      end

      embeds_one :favorites, Favorites, on_replace: :update
    end

    def changeset(model, params) do
      model
      |> cast(params, [:name, :email])
      |> cast_embed(:date_filter, with: &date_filter_changeset/2)
      |> cast_embed(:favorites)
    end

    defp date_filter_changeset(model, params) do
      model
      |> cast(params, [:start_date, :end_date])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@changed} phx-change="update_params" class="space-y-4">
        <.input field={f[:name]} label="Name" />
        <.input field={f[:email]} label="Email" />

        <.inputs_for :let={f} field={f[:date_filter]}>
          <.input type="date" field={f[:start_date]} label="Start Date" />
          <.input type="date" field={f[:end_date]} label="End Date" />
        </.inputs_for>

        <.inputs_for :let={f} field={f[:favorites]}>
          <.input field={f[:flavor]} label="Flavor" />
          <.input
            type="select"
            field={f[:topping]}
            label="Topping"
            options={["sprinkles", "strawberries", "cherries"]}
          />
          <.input
            type="text"
            field={f[:servings]}
            label="Servings (try entering text to see invalid parameter handling)"
          />
        </.inputs_for>
      </.form>

      <label>Last changed</label>
      <% params = inspect(Helpers.to_params_changed_only(@changed), pretty: true) %>
      <pre class="mt-4 bg-gray-100 p-4 rounded-md overflow-x-auto"><%= params %></pre>

      <label>State of the world</label>
      <% state_of_the_world = inspect(Helpers.to_params(@params), pretty: true) %>
      <pre class="mt-4 bg-gray-100 p-4 rounded-md overflow-x-auto"><%= state_of_the_world %></pre>
    </div>
    """
  end

  # Initial parameter handling on page load
  @impl true
  def mount(params, _session, socket) do
    socket = assign(socket, :params, default_params())

    default_params()
    |> Params.changeset(params)
    |> Helpers.handle_changeset_result()
    |> case do
      {:ok, params} ->
        changeset = Params.changeset(default_params(), params)

        socket =
          socket
          |> assign(:params, Changeset.apply_changes(changeset))
          |> assign(:changed, changeset)

        {:ok, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:changed, changeset)
          |> handle_invalid_params(changeset)

        {:ok, socket}
    end
  end

  # Handle parameter changes (e.g., from URL changes or browser navigation)
  @impl true
  def handle_params(params, _uri, socket) do
    # Compare new parameters against current state
    changes = Params.changeset(socket.assigns.params, params)

    case changes do
      # For valid parameters, update the state and track changes
      %Ecto.Changeset{valid?: true} = changeset ->
        new_params = Changeset.apply_changes(changeset)

        socket =
          socket
          # Track what changed for UI feedback
          |> assign(:changed, changeset)
          # Update the complete state
          |> assign(:params, new_params)

        {:noreply, socket}

      # For invalid parameters, remove them and notify user
      invalid_changeset ->
        socket = handle_invalid_params(socket, invalid_changeset)
        {:noreply, socket}
    end
  end

  # Handle form changes from user interaction
  @impl true
  def handle_event("update_params", %{"params" => params}, socket) do
    default_params()
    |> Params.changeset(params)
    |> Helpers.handle_changeset_result()
    |> case do
      {:ok, params} ->
        {:noreply, push_patch(socket, to: build_path(params), replace: true)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, Helpers.format_invalid_param_message(changeset))}
    end
  end

  # Helper to handle invalid parameters
  defp handle_invalid_params(socket, changeset) do
    valid_params =
      changeset
      |> Helpers.to_params_changed_only()

    socket
    |> put_flash(:error, Helpers.format_invalid_param_message(changeset))
    |> push_patch(to: build_path(valid_params), replace: true)
  end

  # Helper to build consistent URLs
  defp build_path(params) do
    qs = if(params == %{}, do: "", else: "?#{Plug.Conn.Query.encode(params)}")
    "/pram#{qs}"
  end

  # Define default parameter values
  defp default_params do
    %Params{
      date_filter: %Params.DateFilter{},
      favorites: %Favorites{}
    }
  end
end
