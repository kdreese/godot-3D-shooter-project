extends Node
## Arguments are passed in in the `--double-dashed` format. After parse_args is called, these will
## be converted to `snake_case` for easy processing.


var used_arg_names: Array[String] = [] ## All the names of arguments that are taken.
var switch_args: Array[SwitchArg] = [] ## Listing of all the possible switch arguments.
var string_args: Array[StringArg] = [] ## Listing of all the possible string arguments.
var int_args: Array[IntArg] = [] ## Listing of all the possible integer arguments.

## The parsed command line arguments, in dictionary form. Populated by parse_args.
var args: Dictionary = {}


## Add a switch (boolean) argument.
func add_switch_arg(arg_name: String) -> void:
	if arg_name in used_arg_names:
		push_error("Argument with identical name already exists.")
		return
	var arg := SwitchArg.new()
	arg.name = arg_name
	switch_args.append(arg)
	used_arg_names.append(arg_name)


## Add a string argument.
func add_string_arg(arg_name: String, default: String = "", required: bool = false) -> void:
	if arg_name in used_arg_names:
		push_error("Argument with identical name already exists.")
		return
	var arg := StringArg.new()
	arg.name = arg_name
	arg.default = default
	arg.required = required
	string_args.append(arg)
	used_arg_names.append(arg_name)


## Add an integer argument.
func add_int_arg(arg_name: String, default: int = 0, required: bool = false) -> void:
	if arg_name in used_arg_names:
		push_error("Argument with identical name already exists.")
		return
	var arg := IntArg.new()
	arg.name = arg_name
	arg.default = default
	arg.required = required
	int_args.append(arg)
	used_arg_names.append(arg_name)


## Parse the arguments from the command line. This should be once after all desired arguments are
## added. Will return `true` if there were no errors, and `false` otherwise. The parsed args are
## stored in the `args` class member.
##
## Note: arguments are passed in in the `--double-dashed` format. After parse_args is called, these
## will be converted to `snake_case` for easy processing.
func parse_args() -> bool:
	var user_args = OS.get_cmdline_user_args()

	args = {}

	for switch_arg in switch_args:
		var formatted_name := switch_arg.name.lstrip("--").replace("-", "_")
		if switch_arg.name in user_args:
			args[formatted_name] = true
		else:
			args[formatted_name] = false

	for string_arg in string_args:
		var formatted_name := string_arg.name.lstrip("--").replace("-", "_")
		var index = user_args.find(string_arg.name)
		if index == -1:
			# The argument was not found.
			if string_arg.required:
				push_error("Missing required argument '%s'" % string_arg.name)
				return false
			else:
				args[formatted_name] = string_arg.default
		else:
			# If this is the end of the arguments list, or if the next argument is not a value,
			# throw an error.
			if index == user_args.size() - 1:
				push_error("Expected value after '%s'" % string_arg.name)
				return false
			elif user_args[index + 1].begins_with("--"):
				push_error("Expected value after '%s', found another argument" % string_arg.name)
				return false
			else:
				args[formatted_name] = user_args[index + 1]

	for int_arg in int_args:
		var formatted_name := int_arg.name.lstrip("--").replace("-", "_")
		var index = user_args.find(int_arg.name)
		if index == -1:
			# The argument was not found.
			if int_arg.required:
				push_error("Missing required argument '%s'" % int_arg.name)
				return false
			else:
				args[formatted_name] = int_arg.default
		else:
			# If this is the end of the arguments list, or if the next argument is not a value,
			# throw an error.
			if index == user_args.size() - 1:
				push_error("Expected value after '%s'" % int_arg.name)
				return false
			elif user_args[index + 1].begins_with("--"):
				push_error("Expected value after '%s', found another argument" % int_arg.name)
				return false
			elif not user_args[index + 1].is_valid_int():
				push_error("Value for int argument '%s' is not a valid integer ('%s')" % [int_arg.name, user_args[index + 1]])
				return false
			else:
				args[formatted_name] = int(user_args[index + 1])

	return true


## Class for switch (boolean) args. If present, their value is true, if not their value is false.
class SwitchArg:
	var name: String


## Class for string value arguments.
class StringArg:
	var name: String
	var default: String
	var required: bool


## Class for integer value arguments.
class IntArg:
	var name: String
	var default: int
	var required: bool
