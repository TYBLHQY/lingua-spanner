#!/usr/bin/env python3
"""AT-SPI word under cursor — called by lingua-spanner ProcessHelper.

Returns the word at the text caret in the focused application.
Uses faster bounded scan: first checks top-level for active app,
then descends into its subtree only.

Requirements: python3 + dbus (standard on all KDE installations)."""

import dbus
import dbus.bus
import signal
import sys

ATSPI_STATE_ACTIVE = 1 << 14   # "active" window/application
GRANULARITY_WORD = 1
TIMEOUT = 2000  # ms per D-Bus call


def get_atspi_bus():
    bus = dbus.SessionBus()
    addr = bus.get_object('org.a11y.Bus', '/org/a11y/bus').GetAddress(
        dbus_interface='org.a11y.Bus')
    return dbus.bus.BusConnection(addr)


def get_children(atspi, bus_name, path):
    try:
        obj = atspi.get_object(bus_name, path)
        return list(obj.GetChildren(
            dbus_interface='org.a11y.atspi.Accessible', timeout=TIMEOUT))
    except Exception:
        return []


def get_interfaces(atspi, bus_name, path):
    try:
        obj = atspi.get_object(bus_name, path)
        return obj.GetInterfaces(
            dbus_interface='org.a11y.atspi.Accessible', timeout=TIMEOUT)
    except Exception:
        return []


def get_caret(atspi, bus_name, path):
    try:
        obj = atspi.get_object(bus_name, path)
        props = dbus.Interface(obj, 'org.freedesktop.DBus.Properties')
        caret = props.Get('org.a11y.atspi.Text', 'CaretOffset',
                          timeout=TIMEOUT)
        return int(caret) if isinstance(caret, dbus.Int32) else -2
    except Exception:
        return -2


def get_word(atspi, bus_name, path, caret):
    try:
        obj = atspi.get_object(bus_name, path)
        text = dbus.Interface(obj, 'org.a11y.atspi.Text')
        result = text.GetStringAtOffset(caret, GRANULARITY_WORD,
                                        timeout=TIMEOUT)
        if result and len(result) >= 1:
            return str(result[0]).strip()
    except Exception:
        pass
    return ''


def main():
    signal.alarm(4)

    try:
        atspi = get_atspi_bus()
    except Exception:
        return

    bus_name = 'org.a11y.atspi.Registry'
    path = '/org/a11y/atspi/accessible/root'

    # Phase 1: Find text under cursor in focused applications.
    # Scan each top-level app up to 3 levels deep.
    for child_bus, child_path in get_children(atspi, bus_name, path):
        # Check if this app or its direct children have a
        # Text object with a caret ≥ 0.
        for node_bus, node_path in (
            (child_bus, child_path),   # the app itself
        ):
            ifaces = get_interfaces(atspi, node_bus, node_path)
            if 'org.a11y.atspi.Text' in ifaces:
                caret = get_caret(atspi, node_bus, node_path)
                if caret >= 0:
                    word = get_word(atspi, node_bus, node_path, caret)
                    if word:
                        print(word, end='')
                        return
            # Check children (1 level deep)
            for sub_bus, sub_path in get_children(atspi, node_bus, node_path):
                sub_ifaces = get_interfaces(atspi, sub_bus, sub_path)
                if 'org.a11y.atspi.Text' in sub_ifaces:
                    caret = get_caret(atspi, sub_bus, sub_path)
                    if caret >= 0:
                        word = get_word(atspi, sub_bus, sub_path, caret)
                        if word:
                            print(word, end='')
                            return
                # Grandchildren (2 levels deep)
                for g_bus, g_path in get_children(atspi, sub_bus, sub_path):
                    ifaces2 = get_interfaces(atspi, g_bus, g_path)
                    if 'org.a11y.atspi.Text' in ifaces2:
                        caret = get_caret(atspi, g_bus, g_path)
                        if caret >= 0:
                            word = get_word(atspi, g_bus, g_path, caret)
                            if word:
                                print(word, end='')
                                return


if __name__ == '__main__':
    main()
