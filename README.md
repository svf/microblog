# microblog
A Chicken Scheme microblog program
My Blog Title
A line of description or whatever you like.
---
2026-05-24 14:03:17 | newest post at the top
2026-05-23 09:11:00 | older post below it

Everything above --- is the header — edit it freely by hand, the program won't touch it. Entries pile up below it, newest first.

# Post text as arguments
csi -script microblog.scm blog.txt This is my first post

# Or piped / interactive
echo "Just woke up" | csi -script microblog.scm blog.txt

# First run creates the file with a default header
csi -script microblog.scm blog.txt Hello world

scp blog.txt user@host:public/blog.txt
rsync -az blog.txt user@host:public/
# or interactively: sftp> put blog.txt

A few design notes:

No external egg dependencies — uses only modules that ship with Chicken 5
isatty? detects whether stdin is a terminal, so it only prints the Post: prompt interactively (pipe-friendly)
The separator comparison is exact — string=? against "---" — so it won't accidentally split on ---- in your prose
If you make the script executable (chmod +x microblog.scm) and your system has csi on PATH, the shebang line lets you run it directly as ./microblog.scm blog.txt your post here


