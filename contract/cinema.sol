// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/** @title System for booking cinema tickets */
contract Cinema {
    struct Session {
        uint256 datetime;
        uint256 seats_count;
        uint256 seat_price;
    }

    struct Film {
        string name;
        string poster_img;
        Session[] sessions;
    }

    struct Booking {
        uint256 ticket_id;
        uint256 film_id;
        uint256 session_id;
        uint256 seat;
        uint256 seat_price;
        uint256 session_datetime;
        uint256 purchase_datetime;
        bool isUsed;
    }

    // contract's owner address
    address owner;

    // addresses of all clients
    address[] public clients;

    // mapping of every user's bookings
    mapping(address => Booking[]) internal bookings;
    uint256 tickets_counter = 0;

    // mapping of all films added
    mapping(uint256 => Film) internal Films_list;
    uint256 films_counter = 0;

    address[] public managers;
    mapping(address => uint256) managers_indices;

    // set owner as contract's deployer
    constructor() {
        owner = msg.sender;
    }

        event NewFilmAdded(
        string name,
        string poster_img
    );

    event NewManagerAdded(
        address manager
    );

    event ManagerRemoved(
        address user
    );

    event BookingPurchaseSuccessful(
        address user
        );

    event TicketStatusChanged(
        address client,
        uint256 ticket_id,
        bool status
    );


    /** @dev returns user's role, it can be owner / manager / owner
     * @param user address of a user
     * @return string role of a user by his address
     */
    function userRole(address user) public view returns (string memory) {
        return
            user == owner
                ? "owner"
                : (isNewManager(user) == false ? "manager" : "client");
    }

    /** @dev checks if user is not a manager
     * @param user address of a user
     * @return bool
     */
    function isNewManager(address user) public view returns (bool) {
        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == user) {
                return false;
            }
        }

        return true;
    }

    /** @dev adds address to managers list
     * @param user address of a user
     */
    function addManager(address user) public {
        require(msg.sender == owner, "Only owner can do this action");

           // Revert if the user is the null address
        require(user != address(0), "Address 0 is not a valid address for a manager");

        // revert if user is already a manager
        require(isNewManager(user) == true, "User is already a manager");

        managers.push(user);
        managers_indices[user] = managers.length - 1;


    }

   function removeManager(address user) public {
    require(msg.sender == owner, "Only owner can do this action");

       // Revert if the user is the null address
    require(user != address(0), "Address 0 is not a valid address for a manager");

    // revert if user is not a manager
    require(isNewManager(user) == false, "User is not a manager");

    uint managerIndex = managers_indices[user];
    uint lastManagerIndex = managers.length - 1;

    // Overwrite the removed manager with the last manager
    managers[managerIndex] = managers[lastManagerIndex];

    // Update the index of the last manager
    managers_indices[managers[managerIndex]] = managerIndex;

    // Delete the reference to the last manager
    delete managers[lastManagerIndex];
    delete managers_indices[user];

    emit ManagerRemoved (user );
}

    

    /**
     * @return address[] addresses of all managers
     */
    function allManagers() public view returns (address[] memory) {
        return managers;
    }

    /** @dev checks if user is a new client of the cinema
     * @param user address of a user
     * @return bool
     */
    function isNewClient(address user) internal view returns (bool) {

            require(isNewManager(msg.sender), "Only managers can access this function");

        for (uint256 i = 0; i < clients.length; i++) {
            if (clients[i] == user) {
                return false;
            }
        }

        return true;
    }

    /** @dev returns all clients that ever purchased tickets
     * @return address[] array of clients addresses
     */
    function allClients() public view returns (address[] memory) {
      require(isNewManager(msg.sender), "Only managers can access this function");
        return clients;
    }

    /** @dev sets status(property isUsed) of a ticket, it can be used(true) or not used (false)
     * @param client address of a user
     * @param ticket_index index of a ticket inside bookings array(tickets index of user starts from 0, but their ticket_id is common for all tickets)
     * @param status status of a ticket
     */
  function setTicketStatus(
    address client,
    uint256 ticket_index,
    bool status
) public {
    // Check if the caller is the ticket owner or a manager
    require(msg.sender == client || isNewManager(msg.sender), "Unauthorized access");

    bookings[client][ticket_index].isUsed = status;
}


    /** @dev returns ticket of user by index
     * @param client address of a user
     * @param ticket_index index of a ticket inside an array
     * @return Booking object
     */
    function getTicket(
        address client,
        uint256 ticket_index
    ) public view returns (Booking memory) {
        require(isNewManager(msg.sender) || msg.sender == client, "Only the ticket owner or a manager can access this function");

        return bookings[client][ticket_index];
    }

    /** @dev returns all tickets of not expired sessions that all users have purchased
     * @return Booking[] array of clients addresses
     */
    function allCurrentTickets() public view returns (Booking[] memory) {
        Booking[] memory current_tickets = new Booking[](tickets_counter);

        uint counter_ = 0;

        // current timestamp
        uint timestamp = block.number;

        for (uint i = 0; i < clients.length; i++) {
            Booking[] memory b = bookings[clients[i]];

            for (uint j = 0; j < b.length; j++) {
                // only retrieve tickets with not expired movie session
                if (b[j].session_datetime >= timestamp) {
                    current_tickets[counter_] = (b[j]);
                    counter_++;
                }
            }
        }

        return current_tickets;
    }

    /** @dev creates new ticket of a film session
     * @param user address of a user
     * @param new_bookings array of new tickets user purchases
     */
    function purchaseBooking(
        address user,
        Booking[] memory new_bookings
    ) public payable {
        // transfer tickets total price to owner
        (bool success, ) = payable(owner).call{value: msg.value}("");

        require(success, "Purchase is failed");

        // if user is a new client, save his address
        if (isNewClient(user)) {
            clients.push(user);

      emit BookingPurchaseSuccessful (user );



        }

        // we need to iterate every array member because of common tickets counter(ticket id)
        for (uint256 i = 0; i < new_bookings.length; i++) {
            bookings[user].push(
                Booking(
                    tickets_counter,
                    new_bookings[i].film_id,
                    new_bookings[i].session_id,
                    new_bookings[i].seat,
                    new_bookings[i].seat_price,
                    new_bookings[i].session_datetime,
                    new_bookings[i].purchase_datetime,
                    false
                )
            );

            tickets_counter++;
        }
    }

    /** @dev returns all tickets(bookings) of a user
     * @param user address of a user
     * @return Booking[] array of client's tickets
     */
    function allBookings(address user) public view returns (Booking[] memory) {
    require(isNewManager(msg.sender), "Only managers can access this function");

        return bookings[user];
    }

    /** @dev adds new film to the cinema movie list
     * @param name_ name of a film
     * @param poster_img_ poster image of a film
     */
    function addFilm(string memory name_, string memory poster_img_) public {
        // check if msg.sender is owner or manager to manipulate with data
        require(
            keccak256(abi.encodePacked(userRole(msg.sender))) !=
                keccak256("client"),
            "You can't do this action"
        );

        // we add a new film this way because sessions property must be empty at this moment
        Film storage f = Films_list[films_counter];

        f.name = name_;
        f.poster_img = poster_img_;

        films_counter++;

       emit NewFilmAdded( name_ , poster_img_);

    }

    /** @dev updates an existing film
     * @param id id of a film
     * @param name_ name of a film
     * @param poster_img_ poster image of a film
     */
    function updateFilm(
        uint256 id,
        string memory name_,
        string memory poster_img_
    ) public {
        // check if msg.sender is owner or manager to manipulate with data
        require(
            keccak256(abi.encodePacked(userRole(msg.sender))) !=
                keccak256("client"),
            "You can't do this action"
        );

        Films_list[id].name = name_;
        Films_list[id].poster_img = poster_img_;
    }

    /** @dev removes film from cinema movie list
     * @param id id of a film
     */
    function removeFilm(uint256 id) public {
        // check if msg.sender is owner or manager to manipulate with data
        require(
            keccak256(abi.encodePacked(userRole(msg.sender))) !=
                keccak256("client"),
            "You can't do this action"
        );

        delete Films_list[id];
    }

    /** @dev adds a session of a film
     * @param film_id index of a film
     * @param new_session object of Session struct
     */
    function addFilmSession(
        uint256 film_id,
        Session memory new_session
    ) public {
        // check if msg.sender is owner or manager to manipulate with data
        require(
            keccak256(abi.encodePacked(userRole(msg.sender))) !=
                keccak256("client"),
            "You can't do this action"
        );

        Films_list[film_id].sessions.push(new_session);
    }

    /** @dev updates a session of a film
     * @param id index of a session
     * @param film_id index of a film
     * @param new_session object of Session struct
     */
    function updateFilmSession(
        uint256 id,
        uint256 film_id,
        Session memory new_session
    ) public {
        // check if msg.sender is owner or manager to manipulate with data
        require(
            keccak256(abi.encodePacked(userRole(msg.sender))) !=
                keccak256("client"),
            "You can't do this action"
        );

        Films_list[film_id].sessions[id] = new_session;
    }

    /** @dev returns all films in cinema movie list
     * @return Film[] array of films added
     */
    function getAllFilms() public view returns (Film[] memory) {
        Film[] memory f = new Film[](films_counter);

        for (uint256 i = 0; i < films_counter; i++) {
            f[i] = Films_list[i];
        }

        return f;
    }

    /** @dev returns session by film's id
     * @param id index of a film
     * @return Session[] array of sessions
     */
    function getFilmSessions(
        uint256 id
    ) public view returns (Session[] memory) {
        return Films_list[id].sessions;
    }

    /** @dev removes specific session from Films_list.sessions array
     * @param id index of a session
     * @param film_id index of a film
     */
    function removeSession(uint256 id, uint256 film_id) public {
        // check if msg.sender is owner or manager to manipulate with data
        require(
            keccak256(abi.encodePacked(userRole(msg.sender))) !=
                keccak256("client"),
            "You can't do this action"
        );

        delete Films_list[film_id].sessions[id];
    }
}