# JsonapiResponses folder
module JsonapiResponses
  # Create a helper to intercept de current_user
  module UserContextProvider
    # Este método se incluirá en el controlador y será accesible en los serializadores
    def serialization_user
      { current_user: current_user }
    end
  end
end
