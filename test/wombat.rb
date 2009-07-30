
class Wombat < ActiveRecord::Base
  
  PREFS = [:send_email, :change_theme, :delete_wombat, :create_wombat]
  has_preferences PREFS
  
  PREFS.each do |p|
    set_default_preference p, true
  end
  
  # def self.preferences_column
  #   "user_prefs"
  # end
  
end