import std.stdio;
import std.string;

import fs = filesystem;
import fsh = shell;


int main(char[][] argv) {
    display_shell_prompt();

    return 0;
}

void display_shell_prompt() {
    string input;
    while (input != "quit") {
        // prompt user for input
        writef("> ");
        stdin.readln(input);

        // strip newline from input
        input = input[0 .. $ - 1];

        // parse input
        switch (input) {
            case "format":
                fsh.format();
            break;

            case "memdmp":
                fsh.memdmp("memdmp.txt");
            break;

            case "save":
                fsh.save("filesystem.bin");
            break;

            case "read":
                fsh.read("filesystem.bin");
            break;

            case "create":

            break;

            case "quit":
                writefln("Good bye");
            break;

            default:
                writefln("No such command: %s", input);
            break;
        }
    }
}
