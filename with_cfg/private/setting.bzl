load(":utils.bzl", "is_bool", "is_int", "is_label", "is_list", "is_string")
load(":select.bzl", "map_attr")

visibility(["//with_cfg/private/...", "//with_cfg/tests/..."])

def validate_and_get_attr_name(setting):
    if is_label(setting):
        # Trigger an early error if the label refers to an invalid repo name.
        # buildifier: disable=no-effect
        setting.workspace_name

        # Ensure that the hash, which is a (signed) 32-bit integer, is non-negative, so that it does
        # not contain a dash, which is not allowed in attribute names. Also ensure that the
        # attribute name starts with a letter as it needs to be a valid identifier.
        return "s_{}_{}".format(hash(str(setting)) + 2147483648, setting.name)
    elif is_string(setting):
        # Strip leading dashes for "did you mean" suggestions as users may have copy-pasted actual
        # command line flags.
        stripped_setting = setting.lstrip("-")
        if not stripped_setting:
            fail("\"{}\" is not a valid setting".format(stripped_setting))
        if stripped_setting[0] in "@/:":
            fail("Custom build settings can only be referenced via Labels, did you mean Label({})?".format(repr(stripped_setting)))
        if setting.startswith("-"):
            fail("\"{}\" is not a valid setting, did you mean \"{}\"?".format(setting, stripped_setting))
        return setting
    else:
        fail("Expected setting to be a Label or a string, got: {} ({})".format(repr(setting), type(setting)))

def get_attr_type(attr):
    mutable_attr_type = [None]

    def update_type(value):
        if not mutable_attr_type[0]:
            mutable_attr_type[0] = _get_type_as_attr_type(value)

    map_attr(update_type, attr)
    if not mutable_attr_type[0]:
        fail("Failed to determine type of attribute '{}'".format(attr))
    return mutable_attr_type[0]

def _get_type_as_attr_type(value):
    suffix = ""
    if is_list(value):
        if not value:
            return None
        inner_value = value[0]
        suffix = "_list"
    else:
        inner_value = value

    if is_string(inner_value):
        return "string" + suffix
    if is_label(inner_value):
        return "label" + suffix
    if is_int(inner_value):
        return "int" + suffix
    if is_bool(inner_value):
        return "bool"

    fail("Failed to determine type of '{}'".format(value))
