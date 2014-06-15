## What is it?

It’s a Ruby script that checks your Gmail account for the *Cha-ching* emails that Bandcamp sends you every time you sell something. Whenever it finds a sale, it grabs a download code from a `.csv` file, feeds it into an email template and sends it to the buyer.

## Why?

We decided to give away a “bonus disc” with our [Not Kings](http://candysays.bandcamp.com/album/not-kings) album. It’s set up as a private album on Bandcamp, and every time someone buys the album we have to email out a download code for the bonus tracks to the buyer.

That got old pretty quickly, so I wrote this script to automate the process. It’s nice because it uses my Gmail account – the outgoing emails end up in my Sent folder, so I can easily check and make sure it’s working well. I also set it up to email me a report each time it sends an email because I’m paranoid about creating a script that accidentally spams all our fans with thousands of messages.

I run this on my shared server using a simple crontab entry to run it every hour, but it will work equally well on a Mac and you can run it manually – it will still save you the hassle of having to find a download code and write an email every time someone buys something. You’ll just need a working version of Ruby (your Mac should have that already).

## Install

To get started, download the repository. Create a set of download codes on Bandcamp, export them and put the `.csv` file in the folder with the script. Create a copy of `config-sample.yml` and name it `config.yml`. Then open up your new config file and change the bits that need changing. The comments should explain what’s needed, including how to filter cha-ching emails for a particular release into a Gmail folder for the script to check.

You’ll also want to edit the email template to say something that’s relevant to you and doesn’t include kisses from Ben & Juju.

The default settings send no email, so you can get run the script without worrying. To do that, `cd` to the directory containing the script, and type `./chaching_checker.rb`. You may need to change the permissions on the file to make it executable: `chmod 755 chaching_checker.rb`.

It will probably tell you that you need to install some Ruby gems, which is true (pretty much the `ruby-gmail` gem and its dependencies). Follow the instructions.

Let me know how it goes! I’d be interested to know if anyone else finds this as useful as me...
