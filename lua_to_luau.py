import os

def rename_lua_to_luau(root_dir):
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith('.lua'):
                lua_path = os.path.join(dirpath, filename)
                luau_path = os.path.join(dirpath, filename[:-4] + '.luau')
                os.rename(lua_path, luau_path)
                print(f'Renamed: {lua_path} -> {luau_path}')

if __name__ == '__main__':
    rename_lua_to_luau('.')
