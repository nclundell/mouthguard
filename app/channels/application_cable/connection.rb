module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id

    def connect
      # Guests need the scoreboard; any new channel must authorize its own subscriptions.
      set_current_user
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
          self.session_id = session.id
        end
      end
  end
end
