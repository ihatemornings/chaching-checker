#!/usr/bin/env ruby
# encoding: UTF-8
require 'gmail'
require 'yaml'

class ChachingChecker

    CONFIG = begin
        YAML.load(File.open("config.yml"))
    rescue ArgumentError => e
        puts "Could not parse your config file: #{e.message}"
    end

    # ----

    def initialize
        fail unless CONFIG
        @gmail = nil
        @purchases = []
        @codes = []
        @email_template = nil
        @emails_delivered = []
        check
    end

    def check
        @gmail = Gmail.new(CONFIG['gmail_username'], CONFIG['gmail_password'])
        get_purchases
        read_codes
        read_email_template
        deliver_emails
        update_codes
        send_report
        @gmail.logout
    end

    private

    def get_purchases
        new_sales_emails = check_email
        new_sales_emails.each do |email|
            date = email.date
            # the IMAP check above only checks by whole day, not time
            next unless date > DateTime.parse(CONFIG['start_date'])

            text_part = email.text_part
            next unless text_part

            if (purchase_details = parse_email(text_part.body))
                @purchases.push(purchase_details)
            end
        end
        @purchases.uniq! { |p| p['Fan Email'] }
        @purchases = find_first_names

        puts "Found #{@purchases.size} purchases since #{CONFIG['start_date']}"
    end

    def check_email
        @gmail.peek = true # don't mark them as read
        @gmail.mailbox(CONFIG['gmail_label']).emails(
            after: Date.parse(CONFIG['start_date'])
        )
    end

    def parse_email(text)
        m = text.to_s.match(/--- cut here ---\n(.*)\n\nPurchased \d/m)
        return nil unless m

        details_text = m[1]

        details = {}
        details_text.split(/\n/).each do |line|
            m = line.match(/^(.*): (.*)$/)
            details[m[1]] = m[2] if m && m[2] != ''
        end
        details
    end

    def find_first_names
        @purchases.map do |p|
            if (name = p['Shipping Name'])
                name.gsub!(/(MR|Mr|mr|MS|Ms|ms|MRS|Mrs|mrs|MISS|Miss|miss)[ \.]*/, '')
                m = name.match(/^(\S+)/)
                if m
                    if m[1].length > 1
                        p['Shipping Name'] = m[1].capitalize
                    else
                        unusable_name = true
                    end
                else
                    unusable_name = true
                end
            else
                unusable_name = true
            end

            if unusable_name
                p['Shipping Name'] = CONFIG['fallback_name']
            end
            p
        end
    end

    Code = Struct.new(:code, :email)

    def read_codes
        file = File.new(CONFIG['csv_filename'], 'r')
        code_pattern = '[0-9a-z]{4}-[0-9a-z]{4}'
        while (line = file.gets)
            m = line.match('^(' + code_pattern + '),?(.*)?$')
            @codes.push(Code.new(m[1], m[2] || nil)) if m
        end
        file.close
        if @codes.empty?
            fail "Couldn't find any codes. Is there a file called #{CONFIG['csv_filename']} around?"
        end
        puts "Read #{@codes.size} codes from code file" if CONFIG['debug_logging']
    rescue => err
        puts "Exception: #{err}"
        err
    end

    def read_email_template
        file = File.new(CONFIG['email_template'], 'r')
        template = ''
        while (line = file.gets)
            template << line
        end
        file.close
        puts "Read email template file" if CONFIG['debug_logging']
        @email_template = template
    rescue => err
        puts "Exception: #{err}"
        err
    end

    def deliver_emails
        @purchases.each do |p|
            name = p['Shipping Name']
            email = p['Fan Email']
            next unless @codes.select { |c| c.email == email }.size.zero?

            unused_code = @codes.select { |c| c.email == '' }.first
            unless unused_code
                puts 'No unused codes left!'
                next
            end

            puts "Found an unused code: #{unused_code.code}" if CONFIG['debug_logging']
            unused_code.email = email
            
            next unless CONFIG['send_emails_to_buyers'] ||
                       (CONFIG['send_first_buyer_email_to_me'] && @emails_delivered.size.zero?)

            if CONFIG['send_first_buyer_email_to_me']
                to_address = CONFIG['my_email']
            else
                to_address = "\"#{name}\" <#{email}>"
            end

            email_template = @email_template

            @gmail.deliver do
                to to_address
                from "\"#{CONFIG['from_name']}\" <#{CONFIG['from_email']}>"
                subject CONFIG['subject']
                text_part do
                    body email_template.sub(
                        '{{name}}', name
                    ).sub(
                        '{{code}}', unused_code.code
                    )
                end
            end
            puts "Delivered code #{unused_code.code} to #{name} <#{email}>" if CONFIG['debug_logging']
            @emails_delivered.push(email)
        end
    end

    def send_report
        if @emails_delivered.empty?
            puts "#{DateTime.now.strftime('%F %T')} Delivered no emails"
            return
        end
        puts "#{DateTime.now.strftime('%F %T')} Delivered emails:"
        @emails_delivered.each { |e| puts "* #{e}" }
        puts "\n\n"
        if CONFIG['send_report_email_to_me']

            alert_body = "Hi #{CONFIG['my_name']},\n\n" \
                         "I just delivered bonus download codes to these people:\n\n"
            @emails_delivered.each { |e| alert_body << "* #{e}\n" }
            alert_body << "\nHope that's ok...\n\nYour faithful autoresponder"

            emails_delivered = @emails_delivered

            @gmail.deliver do
                to "\"#{CONFIG['my_name']}\" <#{CONFIG['my_email']}>"
                from "\"#{CONFIG['from_name']}\" <#{CONFIG['from_email']}>"
                subject "[chaching checker] Sent #{emails_delivered.size} emails"
                text_part do
                    body alert_body
                end
            end
        end
    end

    def update_codes
        unless CONFIG['debug_logging']
            begin
                file = File.new(CONFIG['csv_filename'] + '.tmp', 'w')
                @codes.each do |p|
                    file.puts("#{p.code},#{p.email}")
                end
                file.close
            rescue => err
                puts "Exception: #{err}"
                err
            end

            File.rename CONFIG['csv_filename'] + '.tmp', CONFIG['csv_filename']
        end
    end

end

ChachingChecker.new
