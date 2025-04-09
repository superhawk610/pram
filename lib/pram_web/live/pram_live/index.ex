defmodule PramWeb.PramLive.Index do
  use PramWeb, :live_view

  alias Ecto.Changeset
  import PramWeb.Helpers, only: [changeset_errors: 1]

  defmodule Favorites do
    use Ecto.Schema

    import Ecto.Changeset

    embedded_schema do
      field :flavor, :string, default: "vanilla"
      field :topping, :string, default: "sprinkles"
    end

    def changeset(model, params) do
      model
      |> cast(params, [:flavor, :topping])
    end
  end

  defmodule Params do
    use Ecto.Schema

    import Ecto.Changeset

    embedded_schema do
      field :name, :string
      field :email, :string

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
        </.inputs_for>
      </.form>

      <label>Last changed</label>
      <% params = inspect(to_params_changed_only(@changed), pretty: true) %>
      <pre class="mt-4 bg-gray-100 p-4 rounded-md overflow-x-auto"><%= params %></pre>

      <label>State of the world</label>
      <% state_of_the_world = inspect(to_params(@params), pretty: true) %>
      <pre class="mt-4 bg-gray-100 p-4 rounded-md overflow-x-auto"><%= state_of_the_world %></pre>
    </div>
    """
  end

  # 1. Define the default parameters. Only values that differ
  # from the default are included in the URL.
  defp default_params do
    %Params{
      date_filter: %Params.DateFilter{},
      favorites: %Favorites{}
    }
  end

  # 2. Set the default parameters in the mount.
  @impl true
  def mount(params, _session, socket) do
    changes = Params.changeset(default_params(), params)
    # validate the params
    # ... pop flash messages if there are errors

    # convert to the state of the world
    parsed_params = Changeset.apply_changes(changes)

    # Load page data based on the state of the wolrd
    # .. load data ...
    socket = assign(socket, :params, parsed_params)
    {:ok, socket}
  end

  # 3. The URL parameters only include values that differ from the defaults.
  # To get the full parameters, we need to merge the URL parameters with the
  # default parameters.
  @impl true
  def handle_params(params, _uri, socket) do
    # compare these params to the params you had last time
    changes = Params.changeset(socket.assigns.params, params)

    # Validate the changes, pop up a flash message if there are errors

    # this is where you can load things based on changed params  .
    # ... selectively load data based on the changed params

    # Apply the changes so that the new params become the state of the world
    new_params = Changeset.apply_changes(changes)

    socket = assign(socket, :changed, changes)
    {:noreply, assign(socket, :params, new_params)}
  end

  # 4. When the parameters change, we need to update the URL.
  # We do this by calling `push_patch/3` with *only* the changed parameters.
  @impl true
  def handle_event("update_params", %{"params" => params}, socket) do
    default_params()
    |> Params.changeset(params)
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        params = to_params_changed_only(changeset)
        qs = if(params == %{}, do: "", else: "?#{Plug.Conn.Query.encode(params)}")
        {:noreply, push_patch(socket, to: "/pram#{qs}", replace: true)}

      changeset ->
        {:noreply, put_flash(socket, :error, changeset_errors(changeset))}
    end
  end

  # Note that `changeset.changes` is used to only include changed values.
  defp to_params_changed_only(%Ecto.Changeset{changes: changes}) do
    Map.new(changes, fn
      {key, changeset = %Ecto.Changeset{}} -> {key, to_params_changed_only(changeset)}
      {key, value} -> {key, value}
    end)
  end

  defp to_params(%Date{} = date) do
    date
    |> Date.to_iso8601()
  end

  defp to_params(%_{} = params) do
    params
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {key, to_params(value)} end)
  end

  defp to_params(v), do: v
end
