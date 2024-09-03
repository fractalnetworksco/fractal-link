from clicz import cli_method


class LinkController:

    PLUGIN_NAME = 'link'

    @cli_method
    def init(self) -> None:
        '''
        Initialize the link plugin
        '''
        print("Link plugin initialized!")

    @cli_method
    def say_hello(self, name: str) -> str:
        '''
        Say hello to the user
        ---
        Args:
            name: The name of the user
        ''' 
        print(f"Hello {name}!")

Controller = LinkController