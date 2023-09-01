module cellular_rts

include("gamestate.jl")

using CSFML
using CSFML.LibCSFML


export run_game

function run_game() 
    mode = sfVideoMode(1280, 720, 32)
    
    window = sfRenderWindow_create(mode, "SFML window", sfResize | sfClose, C_NULL)
    @assert window != C_NULL
    
    texture = sfTexture_createFromFile(joinpath(dirname(pathof(CSFML)), "..", "examples", "julia-tan.png"), C_NULL)
    @assert texture != C_NULL
    
    sprite = sfSprite_create()
    sfSprite_setTexture(sprite, texture, sfTrue)
    
    font = sfFont_createFromFile(joinpath(dirname(pathof(CSFML)), "..", "examples", "Roboto-Bold.ttf"))
    @assert font != C_NULL
    
    text = sfText_create()
    sfText_setString(text, "Hello SFML")
    sfText_setFont(text, font)
    sfText_setCharacterSize(text, 50)
    sfText_setFillColor(text, sfColor_fromRGB(255, 125, 0))
    
    music = sfMusic_createFromFile(joinpath(dirname(pathof(CSFML)), "..", "examples", "Chrono_Trigger.ogg"))
    @assert music != C_NULL
    
    # sfMusic_play(music)
    
    event_ref = Ref{sfEvent}()


    # my shit
    circle = sfCircleShape_create()
    sfCircleShape_setPosition(circle, sfVector2f(8f0, 8f0))
    # sfCircleShape_setScale(circle, sfVector2f(80f0, 80f0))
    sfCircleShape_setRadius(circle, 80f0)
    sfCircleShape_setFillColor(circle, sfColor_fromRGB(255, 255, 255))
    
    while Bool(sfRenderWindow_isOpen(window))
        # process events
        while Bool(sfRenderWindow_pollEvent(window, event_ref))
            # close window : exit
            event_ref.x.type == sfEvtClosed && sfRenderWindow_close(window)
        end
        # clear the screen
        sfRenderWindow_clear(window, sfColor_fromRGBA(0,0,0,1))
        # draw the sprite
        # sfRenderWindow_drawSprite(window, sprite, C_NULL)
        # draw the text
        sfRenderWindow_drawText(window, text, C_NULL)

        # draw a circle
        sfRenderWindow_drawCircleShape(window, circle, C_NULL) 

        # update the window
        sfRenderWindow_display(window)
    end
    
    sfMusic_destroy(music)
    sfText_destroy(text)
    sfFont_destroy(font)
    sfSprite_destroy(sprite)
    sfTexture_destroy(texture)
    sfRenderWindow_destroy(window)
end

end # module