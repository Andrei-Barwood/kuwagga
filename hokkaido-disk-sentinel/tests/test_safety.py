from pathlib import Path
from hokkaido_disk_sentinel.safety import check_protection, is_subpath

def test_is_subpath():
    parent = Path("/System")
    child = Path("/System/Library")
    outside = Path("/Users/admin")
    
    assert is_subpath(child, parent) == True
    assert is_subpath(outside, parent) == False
    assert is_subpath(parent, parent) == True

def test_check_protection():
    protected_paths = [Path("/System"), Path("C:\\Windows"), Path("/etc")]
    
    assert check_protection(Path("/System/Library/CoreServices"), protected_paths) == True
    assert check_protection(Path("/System"), protected_paths) == True
    assert check_protection(Path("C:\\Windows\\System32"), protected_paths) == True
    assert check_protection(Path("/etc/hosts"), protected_paths) == True
    
    assert check_protection(Path("/Users/User/Downloads"), protected_paths) == False
    assert check_protection(Path("C:\\Users\\User\\Desktop"), protected_paths) == False
    assert check_protection(Path("/tmp/cache"), protected_paths) == False
