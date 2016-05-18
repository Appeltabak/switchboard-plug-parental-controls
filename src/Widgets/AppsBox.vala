// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2015 Adam Bieńkowski (https://launchpad.net/switchboard-plug-parental-controls)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

namespace PC.Widgets {
    public class AppsBox : Gtk.Box {
        public signal void update_key_file ();

        public string[] targets = {};
        public bool admin = false;
        public bool daemon_active = false;

        private List<AppEntry> entries;
        private Act.User user;

        private Gtk.ListBox list_box;
        private AppChooser apps_popover;
        private Gtk.Switch admin_switch_btn;
        private Gtk.ToolButton remove_button;
        private Gtk.ToolButton clear_button;


        protected class AppEntry : Gtk.ListBoxRow {
            public signal void deleted ();

            private AppInfo info;
            private string executable;

            public AppEntry (AppInfo info) {
                this.info = info;
                executable = info.get_executable ();

                var main_grid = new Gtk.Grid ();
                main_grid.orientation = Gtk.Orientation.HORIZONTAL;

                main_grid.margin = 6;
                main_grid.column_spacing = 12;

                var image = new Gtk.Image.from_gicon (info.get_icon (), Gtk.IconSize.LARGE_TOOLBAR);
                image.pixel_size = 32;
                main_grid.add (image);

                string? description = info.get_description ();
                if (description == null) {
                    description = "";
                }

                string markup = Utils.create_markup (info.get_display_name (), description);
                var label = new Gtk.Label (markup);
                label.expand = true;
                label.use_markup = true;
                label.halign = Gtk.Align.START;
                label.ellipsize = Pango.EllipsizeMode.END;
                main_grid.add (label);

                add (main_grid);
            }

            public AppInfo get_info () {
                return info;
            }

            public string get_executable () {
                return executable;
            }
        }

        public AppsBox (Act.User user) {
            this.user = user;
            entries = new List<AppEntry> ();

            orientation = Gtk.Orientation.VERTICAL;
            spacing = 12;

            var admin_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            var admin_label = new Gtk.Label (_("Allow access to these apps with admin permission:"));
            admin_box.add (admin_label);

            admin_switch_btn = new Gtk.Switch ();
            admin_switch_btn.notify["active"].connect (on_changed);
            admin_box.add (admin_switch_btn);

            var frame = new Gtk.Frame (null);
            frame.hexpand = frame.vexpand = true;

            Gdk.RGBA bg = { 1, 1, 1, 1 };
            frame.override_background_color (0, bg);

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            frame.add (main_box);

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.hexpand = scrolled.vexpand = true;

            var header_label = new Gtk.Label (_("Add apps to prevent %s from using them:").printf (user.get_real_name ()));
            header_label.margin_start = 6;
            header_label.halign = Gtk.Align.START;
            header_label.get_style_context ().add_class ("h4");

            main_box.add (header_label);

            list_box = new Gtk.ListBox ();
            list_box.row_selected.connect (on_changed);
            scrolled.add (list_box);

            var toolbar = new Gtk.Toolbar ();
            toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
            toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;

            var add_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON), null);
            add_button.tooltip_text = _("Add Prevented Apps…");
            add_button.clicked.connect (on_add_button_clicked);

            remove_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("list-remove-symbolic", Gtk.IconSize.BUTTON), null);
            remove_button.tooltip_text = _("Remove Selected App");
            remove_button.sensitive = false;
            remove_button.clicked.connect (on_remove_button_clicked);

            var expander = new Gtk.ToolItem ();
            expander.set_expand (true);
            expander.visible_vertical = false;

            clear_button = new Gtk.ToolButton (null, _("Clear"));
            clear_button.sensitive = false;
            clear_button.clicked.connect (on_clear_button_clicked);

            apps_popover = new AppChooser (add_button);
            apps_popover.app_chosen.connect (load_info);

            toolbar.add (add_button);
            toolbar.add (remove_button);
            toolbar.add (expander);
            toolbar.add (clear_button);

            main_box.add (scrolled);
            main_box.add (toolbar);

            add (frame);
            add (admin_box);

            load_existing ();
            show_all ();
        }

        public bool get_active () {
            return daemon_active;
        } 

        public void set_active (bool active) {
            daemon_active = active;
            on_changed ();
        }

        private void on_add_button_clicked () {
            apps_popover.show_all ();
        }

        private void on_remove_button_clicked () {
            var entry = (AppEntry) list_box.get_selected_row ();
            entry.deleted ();
        }

        private void on_clear_button_clicked () {
            foreach (var entry in entries) {
                Idle.add (() => {
                    entry.deleted ();
                    return false;
                });
            }
        }

        private void load_info (AppInfo info) {
            if (!get_info_loaded (info)) {
                var row = new AppEntry (info);
                row.deleted.connect (on_deleted);

                entries.append (row);
                list_box.add (row);
                list_box.show_all ();
                on_changed ();
            }
        }

        private bool get_info_loaded (AppInfo info) {
            foreach (var entry in entries) {
                if (entry.get_info () == info) {
                    return true;
                }
            }

            return false;
        }

        private void on_deleted (AppEntry row) {
            entries.remove (row);
            row.destroy ();
            on_changed ();
        }

        private void on_changed () {
            remove_button.sensitive = (list_box.get_selected_row () != null);
            clear_button.sensitive = (entries.length () > 0);

            string[] _targets = {};
            foreach (var entry in entries) {
                _targets += Environment.find_program_in_path (entry.get_executable ());
            }

            admin = admin_switch_btn.get_active ();
            targets = _targets;
            update_key_file ();
        }

        private void load_existing () {
            var key_file = new KeyFile ();
            try {
                key_file.load_from_file (Utils.build_daemon_conf_path (user), 0);
                string[] _targets = key_file.get_string_list (Vars.DAEMON_GROUP, Vars.DAEMON_KEY_TARGETS);
                daemon_active = key_file.get_boolean (Vars.DAEMON_GROUP, Vars.DAEMON_KEY_ACTIVE);
                foreach (var info in AppInfo.get_all ()) {
                    if (info.should_show ()
                        && Environment.find_program_in_path (info.get_executable ()) in _targets) {
                        load_info (info);
                    }
                }
            } catch (KeyFileError e) {
                warning ("%s\n", e.message);
            } catch (FileError e) {
                warning ("%s\n", e.message);
            }
        }
    }
}
