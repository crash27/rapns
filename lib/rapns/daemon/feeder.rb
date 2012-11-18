module Rapns
  module Daemon
    class Feeder
      extend InterruptibleSleep
      extend DatabaseReconnectable

      def self.name
        'Feeder'
      end

      def self.start(poll)
        loop do
          break if @stop
          deliver_notifications
          interruptible_sleep poll
        end
      end

      def self.stop
        @stop = true
        interrupt_sleep
      end

      protected

      def self.deliver_notifications
        begin
          with_database_reconnect_and_retry do
            batch_size = Rapns::Daemon.config.batch_size
            idle = Rapns::Daemon::AppRunner.idle.map(&:app)
            Rapns::Notification.ready_for_delivery.for_apps(idle).limit(batch_size).each do |notification|
              Rapns::Daemon::AppRunner.deliver(notification)
            end
          end
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        end
      end
    end
  end
end
