require "sidekiq"
require "sidekiq/logging/json/version"

module Sidekiq
  module Logging
    module Json
      class Logger < Sidekiq::Logging::Pretty
        def call(severity, time, program_name, message)
          event = LogStash::Event.new
          process_message(message).each do |key, value|
            event[key] = value
          end
          event['severity'] = severity
          event['tid'] = Thread.current.object_id.to_s(36)
          event['worker'] = "#{context}".split(" ")[0]
          event.to_json + "\n"
        end

        private

        def process_message(message)
          case message
          when Exception
            {
              'status' => 'exception',
              'message' => message.message
            }
          when Hash
            if message["retry"]
              {
                'status' => 'retry',
                'message' => "#{message['class']} failed, retrying with args #{message['args']}."
              }
            else
              {
                'status' => 'dead',
                'message' => "#{message['class']} failed with args #{message['args']}, not retrying."
              }
            end
          else
            result = message.split(" ")
            status = result[0].match(/^(start|done|fail):?$/) || []

            {
              'status' => status[1],                                   # start or done
              'duration' => status[1] && result[1] && result[1].to_f,  # run time in seconds
              'message' => message
            }
          end
        end
      end
    end
  end
end
