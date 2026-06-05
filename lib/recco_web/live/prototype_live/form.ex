defmodule ReccoWeb.PrototypeLive.Form do
  use ReccoWeb, :live_view

  alias Ecto.Changeset
  alias Recco.BoardGames
  alias Recco.Prototypes
  alias Recco.Prototypes.Prototype
  alias Recco.Prototypes.Storage

  @max_images 10
  @max_file_size 10 * 1024 * 1024

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        all_categories: BoardGames.list_categories(),
        all_mechanics: BoardGames.list_mechanics(),
        max_images: @max_images
      )
      |> allow_upload(:images,
        accept: Storage.allowed_extensions(),
        max_entries: @max_images,
        max_file_size: @max_file_size
      )

    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    apply_action(socket, socket.assigns.live_action, params)
  end

  defp apply_action(socket, :new, _params) do
    user = socket.assigns.current_user

    socket
    |> assign(
      page_title: gettext("Submit a prototype"),
      prototype: nil,
      mode: :new,
      categories: [],
      mechanics: [],
      collaborators: [%{"name" => "", "role" => ""}],
      links: [],
      existing_images: []
    )
    |> assign_form(%Prototype{user_id: user.id, contact_email: user.email}, %{})
    |> noreply()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    prototype = Prototypes.get_prototype!(id)

    if Prototypes.owns?(prototype, socket.assigns.current_user) do
      socket
      |> assign(
        page_title: gettext("Edit prototype"),
        prototype: prototype,
        mode: :edit,
        categories: prototype.categories,
        mechanics: prototype.mechanics,
        collaborators: collaborators_to_maps(prototype.collaborators),
        links: links_to_maps(prototype.links),
        existing_images: prototype.images
      )
      |> assign_form(prototype, %{})
      |> noreply()
    else
      socket
      |> put_flash(:error, gettext("You can only edit your own prototypes"))
      |> redirect(to: ~p"/prototypes")
      |> noreply()
    end
  end

  defp noreply(socket), do: {:noreply, socket}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("validate", params, socket) do
    collaborators = parse_collaborators(params["collab"])
    links = parse_links(params["link"])
    prototype_params = Map.get(params, "prototype", %{})

    socket =
      socket
      |> assign(collaborators: collaborators, links: links)
      |> assign_form(
        base_struct(socket),
        merge_side_state(prototype_params, socket, collaborators, links),
        action: :validate
      )

    {:noreply, socket}
  end

  def handle_event("save", params, socket) do
    collaborators = parse_collaborators(params["collab"])
    links = parse_links(params["link"])
    prototype_params = Map.get(params, "prototype", %{})
    attrs = merge_side_state(prototype_params, socket, collaborators, links)

    socket = assign(socket, collaborators: collaborators, links: links)

    case persist(socket, attrs) do
      {:ok, prototype} ->
        :ok = consume_uploads(socket, prototype)

        {:noreply,
         socket
         |> put_flash(:info, save_flash(socket.assigns.mode))
         |> redirect(to: ~p"/prototypes/#{prototype.id}")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, gettext("Not allowed"))}

      {:error, :unprocessable_entity, _errors} ->
        {:noreply, assign_form(socket, base_struct(socket), attrs, action: :insert)}
    end
  end

  def handle_event("filter_categories", %{"selected" => selected}, socket) do
    socket = assign(socket, categories: selected)
    prototype_params = current_prototype_params(socket)
    {:noreply, assign_form(socket, base_struct(socket), prototype_params, action: :validate)}
  end

  def handle_event("filter_mechanics", %{"selected" => selected}, socket) do
    socket = assign(socket, mechanics: selected)
    prototype_params = current_prototype_params(socket)
    {:noreply, assign_form(socket, base_struct(socket), prototype_params, action: :validate)}
  end

  def handle_event("add_collab", _params, socket) do
    collaborators = socket.assigns.collaborators ++ [%{"name" => "", "role" => ""}]
    {:noreply, assign(socket, collaborators: collaborators)}
  end

  def handle_event("remove_collab", %{"index" => idx}, socket) do
    index = String.to_integer(idx)
    collaborators = List.delete_at(socket.assigns.collaborators, index)
    {:noreply, assign(socket, collaborators: collaborators)}
  end

  def handle_event("add_link", _params, socket) do
    links = socket.assigns.links ++ [%{"label" => "", "url" => ""}]
    {:noreply, assign(socket, links: links)}
  end

  def handle_event("remove_link", %{"index" => idx}, socket) do
    index = String.to_integer(idx)
    links = List.delete_at(socket.assigns.links, index)
    {:noreply, assign(socket, links: links)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  def handle_event("delete_image", %{"id" => image_id}, socket) do
    image = Enum.find(socket.assigns.existing_images, &(&1.id == image_id))

    if image do
      case Prototypes.delete_image(image, socket.assigns.current_user) do
        {:ok, _} ->
          existing = Enum.reject(socket.assigns.existing_images, &(&1.id == image_id))
          {:noreply, assign(socket, existing_images: existing)}

        {:error, :forbidden} ->
          {:noreply, put_flash(socket, :error, gettext("Not allowed"))}
      end
    else
      {:noreply, socket}
    end
  end

  defp persist(%{assigns: %{mode: :new, current_user: user}}, attrs) do
    Prototypes.create_prototype(user, attrs)
  end

  defp persist(%{assigns: %{mode: :edit, prototype: prototype, current_user: user}}, attrs) do
    Prototypes.update_prototype(prototype, user, attrs)
  end

  defp consume_uploads(socket, prototype) do
    consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
      case Storage.store(prototype.id, path, entry.client_name) do
        {:ok, stored_path} ->
          _ = Prototypes.add_image(prototype, stored_path, entry.client_name)
          {:ok, stored_path}

        {:error, _} = err ->
          err
      end
    end)

    :ok
  end

  defp base_struct(%{assigns: %{mode: :new, current_user: user}}) do
    %Prototype{user_id: user.id}
  end

  defp base_struct(%{assigns: %{mode: :edit, prototype: prototype}}), do: prototype

  defp current_prototype_params(socket) do
    cs = socket.assigns.form.source

    %{
      "title" => Changeset.get_field(cs, :title) || "",
      "description" => Changeset.get_field(cs, :description) || "",
      "min_players" => to_string(Changeset.get_field(cs, :min_players) || ""),
      "max_players" => to_string(Changeset.get_field(cs, :max_players) || ""),
      "min_playtime" => to_string(Changeset.get_field(cs, :min_playtime) || ""),
      "max_playtime" => to_string(Changeset.get_field(cs, :max_playtime) || ""),
      "contact_email" => Changeset.get_field(cs, :contact_email) || ""
    }
  end

  defp assign_form(socket, struct, prototype_params, opts \\ []) do
    attrs =
      merge_side_state(
        prototype_params,
        socket,
        socket.assigns[:collaborators] || [],
        socket.assigns[:links] || []
      )

    changeset = Prototype.changeset(struct, attrs)

    changeset =
      case Keyword.get(opts, :action) do
        nil -> changeset
        action -> Map.put(changeset, :action, action)
      end

    assign(socket, form: to_form(changeset, as: :prototype))
  end

  defp merge_side_state(prototype_params, socket, collaborators, links) do
    prototype_params
    |> Map.put("categories", socket.assigns[:categories] || [])
    |> Map.put("mechanics", socket.assigns[:mechanics] || [])
    |> Map.put("collaborators", collaborators)
    |> Map.put("links", links)
  end

  defp parse_collaborators(nil), do: [%{"name" => "", "role" => ""}]

  defp parse_collaborators(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map(fn {_idx, attrs} ->
      %{"name" => attrs["name"] || "", "role" => attrs["role"] || ""}
    end)
    |> case do
      [] -> [%{"name" => "", "role" => ""}]
      list -> list
    end
  end

  defp parse_links(nil), do: []

  defp parse_links(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map(fn {_idx, attrs} ->
      %{"label" => attrs["label"] || "", "url" => attrs["url"] || ""}
    end)
  end

  defp collaborators_to_maps(collabs) when is_list(collabs) do
    Enum.map(collabs, fn c -> %{"name" => c.name || "", "role" => c.role || ""} end)
  end

  defp links_to_maps(links) when is_list(links) do
    Enum.map(links, fn l -> %{"label" => l.label || "", "url" => l.url || ""} end)
  end

  defp save_flash(:new), do: gettext("Prototype submitted!")
  defp save_flash(:edit), do: gettext("Prototype updated!")

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto space-y-6">
      <.link
        navigate={~p"/prototypes"}
        class="inline-flex items-center text-sm font-heading hover:bg-main px-2 py-1 rounded-base"
      >
        ← {gettext("Back to prototypes")}
      </.link>

      <h1 class="text-2xl font-heading">{@page_title}</h1>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6 rounded-base border-2 border-border bg-bw p-6 shadow-brutalist"
      >
        <.input field={@form[:title]} type="text" label={gettext("Title")} required />

        <div>
          <label for={@form[:description].id} class="mb-1 block text-sm font-bold">
            {gettext("Description")}
          </label>
          <textarea
            id={@form[:description].id}
            name={@form[:description].name}
            rows="6"
            required
            class="w-full rounded-base border-2 border-border bg-bw px-3 py-2 text-sm font-medium placeholder:text-fg/50 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
          >{Phoenix.HTML.Form.normalize_value("textarea", @form[:description].value)}</textarea>
          <p
            :for={msg <- field_errors(@form, :description)}
            class="mt-1 text-sm font-medium text-red-600"
          >
            {msg}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:min_players]}
            type="number"
            min="1"
            label={gettext("Min players")}
            required
          />
          <.input
            field={@form[:max_players]}
            type="number"
            min="1"
            label={gettext("Max players")}
            required
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:min_playtime]}
            type="number"
            min="1"
            label={gettext("Min playtime (min)")}
            required
          />
          <.input
            field={@form[:max_playtime]}
            type="number"
            min="1"
            label={gettext("Max playtime (min)")}
            required
          />
        </div>

        <.multi_select
          id="prototype-category-picker"
          label={gettext("Categories")}
          options={@all_categories}
          selected={@categories}
          event="filter_categories"
          placeholder={gettext("Pick at least one")}
        />
        <p
          :for={msg <- field_errors(@form, :categories)}
          class="text-sm font-base text-red-600"
        >
          {msg}
        </p>

        <.multi_select
          id="prototype-mechanic-picker"
          label={gettext("Mechanics")}
          options={@all_mechanics}
          selected={@mechanics}
          event="filter_mechanics"
          placeholder={gettext("Pick at least one")}
        />
        <p
          :for={msg <- field_errors(@form, :mechanics)}
          class="text-sm font-base text-red-600"
        >
          {msg}
        </p>

        <section class="space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="font-heading">{gettext("Team")}</h2>
            <button
              type="button"
              phx-click="add_collab"
              class="rounded-base border-2 border-border bg-bw px-3 py-1 text-sm font-heading hover:bg-main transition-colors"
            >
              + {gettext("Add member")}
            </button>
          </div>
          <div :for={{collab, idx} <- Enum.with_index(@collaborators)} class="grid grid-cols-12 gap-2">
            <input
              type="text"
              name={"collab[#{idx}][name]"}
              value={collab["name"]}
              placeholder={gettext("Name")}
              class="col-span-5 h-10 rounded-base border-2 border-border bg-bw px-3 text-sm font-base focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <input
              type="text"
              name={"collab[#{idx}][role]"}
              value={collab["role"]}
              placeholder={gettext("Role (e.g. designer)")}
              class="col-span-6 h-10 rounded-base border-2 border-border bg-bw px-3 text-sm font-base focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <button
              type="button"
              phx-click="remove_collab"
              phx-value-index={idx}
              class="col-span-1 h-10 rounded-base border-2 border-border bg-red-300 text-sm font-heading hover:translate-x-shadow-x hover:translate-y-shadow-y transition-all"
              aria-label={gettext("Remove member")}
            >
              ×
            </button>
          </div>
        </section>

        <section class="space-y-3">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="font-heading">{gettext("Links")}</h2>
              <p class="text-xs font-base text-fg/70">
                {gettext("Landing pages, crowdfunding, social — anything you want to share.")}
              </p>
            </div>
            <button
              type="button"
              phx-click="add_link"
              class="rounded-base border-2 border-border bg-bw px-3 py-1 text-sm font-heading hover:bg-main transition-colors"
            >
              + {gettext("Add link")}
            </button>
          </div>
          <div :for={{link, idx} <- Enum.with_index(@links)} class="grid grid-cols-12 gap-2">
            <input
              type="text"
              name={"link[#{idx}][label]"}
              value={link["label"]}
              placeholder={gettext("Label (e.g. Kickstarter)")}
              class="col-span-4 h-10 rounded-base border-2 border-border bg-bw px-3 text-sm font-base focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <input
              type="url"
              name={"link[#{idx}][url]"}
              value={link["url"]}
              placeholder="https://..."
              class="col-span-7 h-10 rounded-base border-2 border-border bg-bw px-3 text-sm font-base focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <button
              type="button"
              phx-click="remove_link"
              phx-value-index={idx}
              class="col-span-1 h-10 rounded-base border-2 border-border bg-red-300 text-sm font-heading hover:translate-x-shadow-x hover:translate-y-shadow-y transition-all"
              aria-label={gettext("Remove link")}
            >
              ×
            </button>
          </div>
        </section>

        <.input
          field={@form[:contact_email]}
          type="email"
          label={gettext("Contact email")}
          required
        />

        <section class="space-y-3">
          <h2 class="font-heading">{gettext("Images")}</h2>

          <div :if={@existing_images != []} class="grid grid-cols-3 sm:grid-cols-4 gap-2">
            <div
              :for={image <- @existing_images}
              class="relative aspect-square rounded-base border-2 border-border bg-bg overflow-hidden"
            >
              <img
                src={~p"/prototype_images/#{image.id}"}
                alt={image.original_filename}
                class="w-full h-full object-cover"
              />
              <button
                type="button"
                phx-click="delete_image"
                phx-value-id={image.id}
                data-confirm={gettext("Remove this image?")}
                class="absolute top-1 right-1 rounded-base border-2 border-border bg-red-300 w-7 h-7 flex items-center justify-center text-sm font-heading"
                aria-label={gettext("Delete image")}
              >
                ×
              </button>
            </div>
          </div>

          <label class="block rounded-base border-2 border-dashed border-border bg-bg p-6 text-center cursor-pointer hover:bg-bw transition-colors">
            <.live_file_input upload={@uploads.images} class="hidden" />
            <span class="font-heading text-sm">
              {gettext("Drop images here or click to upload")}
            </span>
            <span class="block text-xs font-base text-fg/70 mt-1">
              {gettext("Up to %{count} images, max 10 MB each", count: @max_images)}
            </span>
          </label>

          <div :if={@uploads.images.entries != []} class="grid grid-cols-3 sm:grid-cols-4 gap-2">
            <div
              :for={entry <- @uploads.images.entries}
              class="relative aspect-square rounded-base border-2 border-border bg-bg overflow-hidden"
            >
              <.live_img_preview entry={entry} class="w-full h-full object-cover" />
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="absolute top-1 right-1 rounded-base border-2 border-border bg-red-300 w-7 h-7 flex items-center justify-center text-sm font-heading"
                aria-label={gettext("Cancel upload")}
              >
                ×
              </button>
              <p
                :for={err <- upload_errors(@uploads.images, entry)}
                class="absolute bottom-0 inset-x-0 bg-red-300 text-xs px-1 py-0.5"
              >
                {upload_error_message(err)}
              </p>
            </div>
          </div>

          <p
            :for={err <- upload_errors(@uploads.images)}
            class="text-sm font-base text-red-600"
          >
            {upload_error_message(err)}
          </p>
        </section>

        <button
          type="submit"
          class="rounded-base border-2 border-border bg-main px-4 py-2.5 text-sm font-heading shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          {if @mode == :new, do: gettext("Submit prototype"), else: gettext("Save changes")}
        </button>
      </.form>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :selected, :list, required: true
  attr :event, :string, required: true
  attr :placeholder, :string, default: "Select..."

  defp multi_select(assigns) do
    options_json = Jason.encode!(Enum.map(assigns.options, &%{name: &1.name}))
    selected_json = Jason.encode!(assigns.selected)
    assigns = assign(assigns, options_json: options_json, selected_json: selected_json)

    ~H"""
    <div>
      <label class="mb-1 block text-sm font-heading">{@label}</label>
      <div
        id={@id}
        phx-hook="MultiSelect"
        data-options={@options_json}
        data-selected={@selected_json}
        data-event={@event}
        class="relative"
      >
        <div
          data-header
          tabindex="0"
          role="combobox"
          aria-expanded="false"
          aria-haspopup="listbox"
          class="flex flex-wrap items-center gap-1 min-h-[2.5rem] w-full rounded-base border-2 border-border bg-bw px-3 py-1.5 cursor-pointer"
        >
          <span data-tags class="flex flex-wrap gap-1"></span>
          <span data-placeholder class="text-sm text-fg/50 font-base">{@placeholder}</span>
          <span class="ml-auto pl-2">
            <svg class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
                clip-rule="evenodd"
              />
            </svg>
          </span>
        </div>
        <div
          data-dropdown
          role="listbox"
          class="hidden absolute top-full left-0 right-0 z-50 mt-1 rounded-base border-2 border-border bg-bw shadow-brutalist max-h-[40dvh] overflow-y-auto"
        >
          <div class="p-2 border-b-2 border-border">
            <input
              data-search
              type="text"
              placeholder="Search..."
              class="w-full rounded-base border-2 border-border bg-bw px-3 py-1.5 text-sm font-base placeholder:text-fg/50 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-1"
            />
          </div>
          <div data-options class="p-1"></div>
        </div>
      </div>
    </div>
    """
  end

  defp field_errors(form, field) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.map(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp upload_error_message(:too_large), do: gettext("File is too large")
  defp upload_error_message(:not_accepted), do: gettext("File type not accepted")
  defp upload_error_message(:too_many_files), do: gettext("Too many files")
  defp upload_error_message(err), do: to_string(err)

  @spec max_images() :: pos_integer()
  def max_images, do: @max_images
end
