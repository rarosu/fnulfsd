module shell;

import std.stdio;
import fs = filesystem;


void format() {
    fs.format();
}

//void quit() {
//    writefln("Good bye");
//}

void save(string filename) {
    fs.save_fs(filename);
}

void read(string filename) {
    fs.load_fs(filename);
}

void memdmp(string filename) {
    fs.memdmp(filename);
}

void create(string filename, fs.Address parent, string data) {

}

bool mkdir(string name, fs.Address parent) {
    if (fs.create_directory(name, parent) != fs.E_BLOCK_NOT_FOUND)
        return false;
    return true;
}
