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
    <div class="max-w-3xl mx-auto pb-12 space-y-6">
      <.link navigate={~p"/prototypes"} class="btn btn-ghost btn-sm !pl-0">
        ← {gettext("Back to prototypes")}
      </.link>

      <div>
        <div class="label mb-2">
          {if @mode == :new, do: gettext("New submission"), else: gettext("Editing")}
        </div>
        <h1 class="text-[clamp(34px,4vw,58px)]">{@page_title}</h1>
      </div>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6 panel p-6">
        <.input field={@form[:title]} type="text" label={gettext("Title")} required />

        <div>
          <label for={@form[:description].id} class="label label-ink !font-bold block mb-2">
            {gettext("Description")}
          </label>
          <textarea
            id={@form[:description].id}
            name={@form[:description].name}
            rows="6"
            required
            class="field"
          >{Phoenix.HTML.Form.normalize_value("textarea", @form[:description].value)}</textarea>
          <p
            :for={msg <- field_errors(@form, :description)}
            class="mt-1.5 text-sm font-semibold text-danger"
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
          class="text-sm font-semibold text-danger"
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
          class="text-sm font-semibold text-danger"
        >
          {msg}
        </p>

        <section class="space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="text-xl">{gettext("Team")}</h2>
            <button type="button" phx-click="add_collab" class="btn btn-sm">
              + {gettext("Add member")}
            </button>
          </div>
          <div
            :for={{collab, idx} <- Enum.with_index(@collaborators)}
            class="grid grid-cols-12 gap-2"
          >
            <input
              type="text"
              name={"collab[#{idx}][name]"}
              value={collab["name"]}
              placeholder={gettext("Name")}
              class="field col-span-5 !py-2 !text-sm"
            />
            <input
              type="text"
              name={"collab[#{idx}][role]"}
              value={collab["role"]}
              placeholder={gettext("Role (e.g. designer)")}
              class="field col-span-6 !py-2 !text-sm"
            />
            <button
              type="button"
              phx-click="remove_collab"
              phx-value-index={idx}
              class="btn btn-sm col-span-1 !p-0 grid place-items-center hover:!bg-danger hover:!text-accent-ink"
              aria-label={gettext("Remove member")}
            >
              ×
            </button>
          </div>
        </section>

        <section class="space-y-3">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h2 class="text-xl">{gettext("Links")}</h2>
              <p class="text-ink-soft text-sm mt-1">
                {gettext("Landing pages, crowdfunding, social — anything you want to share.")}
              </p>
            </div>
            <button type="button" phx-click="add_link" class="btn btn-sm whitespace-nowrap">
              + {gettext("Add link")}
            </button>
          </div>
          <div :for={{link, idx} <- Enum.with_index(@links)} class="grid grid-cols-12 gap-2">
            <input
              type="text"
              name={"link[#{idx}][label]"}
              value={link["label"]}
              placeholder={gettext("Label (e.g. Kickstarter)")}
              class="field col-span-4 !py-2 !text-sm"
            />
            <input
              type="url"
              name={"link[#{idx}][url]"}
              value={link["url"]}
              placeholder="https://..."
              class="field col-span-7 !py-2 !text-sm"
            />
            <button
              type="button"
              phx-click="remove_link"
              phx-value-index={idx}
              class="btn btn-sm col-span-1 !p-0 grid place-items-center hover:!bg-danger hover:!text-accent-ink"
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
          <h2 class="text-xl">{gettext("Images")}</h2>

          <div :if={@existing_images != []} class="grid grid-cols-3 sm:grid-cols-4 gap-2">
            <div
              :for={image <- @existing_images}
              class="relative aspect-square border-bw border-line rounded-panel-sm bg-card2 overflow-hidden"
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
                class="btn btn-sm absolute top-1 right-1 !w-7 !h-7 !p-0 grid place-items-center !bg-danger !text-accent-ink"
                aria-label={gettext("Delete image")}
              >
                ×
              </button>
            </div>
          </div>

          <label class="block border-2 border-dashed border-line bg-card2 rounded-panel p-6 text-center cursor-pointer hover:bg-card transition-colors">
            <.live_file_input upload={@uploads.images} class="hidden" />
            <span class="font-bold text-sm">
              {gettext("Drop images here or click to upload")}
            </span>
            <span class="block text-ink-soft text-xs mt-1">
              {gettext("Up to %{count} images, max 10 MB each", count: @max_images)}
            </span>
          </label>

          <div :if={@uploads.images.entries != []} class="grid grid-cols-3 sm:grid-cols-4 gap-2">
            <div
              :for={entry <- @uploads.images.entries}
              class="relative aspect-square border-bw border-line rounded-panel-sm bg-card2 overflow-hidden"
            >
              <.live_img_preview entry={entry} class="w-full h-full object-cover" />
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="btn btn-sm absolute top-1 right-1 !w-7 !h-7 !p-0 grid place-items-center !bg-danger !text-accent-ink"
                aria-label={gettext("Cancel upload")}
              >
                ×
              </button>
              <p
                :for={err <- upload_errors(@uploads.images, entry)}
                class="absolute bottom-0 inset-x-0 bg-danger text-accent-ink text-xs px-1 py-0.5 font-semibold"
              >
                {upload_error_message(err)}
              </p>
            </div>
          </div>

          <p
            :for={err <- upload_errors(@uploads.images)}
            class="text-sm font-semibold text-danger"
          >
            {upload_error_message(err)}
          </p>
        </section>

        <button type="submit" class="btn btn-primary btn-lg w-full justify-center">
          {if @mode == :new, do: gettext("Submit prototype"), else: gettext("Save changes")} →
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
      <label class="label label-ink !font-bold block mb-2">{@label}</label>
      <div
        id={@id}
        phx-hook="MultiSelect"
        data-options={@options_json}
        data-selected={@selected_json}
        data-event={@event}
        class="ms"
      >
        <div
          data-header
          tabindex="0"
          role="combobox"
          aria-expanded="false"
          aria-haspopup="listbox"
          class="ms-trigger"
        >
          <span data-tags class="flex flex-wrap gap-1.5 items-center"></span>
          <span data-placeholder class="text-ink-soft text-sm">{@placeholder}</span>
          <span class="font-mono text-xs opacity-70 ml-auto">▼</span>
        </div>
        <div data-dropdown role="listbox" class="ms-pop hidden">
          <div class="p-1.5 border-b-bw border-line">
            <input
              data-search
              type="text"
              placeholder={gettext("Search…")}
              class="w-full px-2.5 py-1.5 text-sm font-medium bg-card border-2 border-line rounded-panel-sm text-ink placeholder:text-ink-soft focus:outline-none"
            />
          </div>
          <div data-options></div>
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
