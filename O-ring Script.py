import matplotlib.pyplot as plt


def calculate_o_ring_params(ring_thickness, ring_ID, ring_OD, groove_depth=None, compression_range=(8, 35)):
    # Given O-Tank ID
    o_tank_ID = 3.25  # inches

    valid_combinations = []
    machine_gaps = []
    compressions = []

    if groove_depth is not None:
        for machine_gap in [j * 0.001 for j in range(10, 101)]:  # Machine gap between 0.01 and 0.1 inches
            bulkhead_ID = o_tank_ID - (groove_depth * 2) - machine_gap
            stretch = (bulkhead_ID - ring_ID) / ring_ID
            crossR = 0.5 * stretch
            new_OD = (ring_ID * (1 + stretch)) + (ring_thickness * 2 * (1 - crossR))
            compression = (((ring_thickness * 2 * (1 - crossR)) - (o_tank_ID - bulkhead_ID)) / (
                        ring_thickness * 2 * (1 - crossR)) * 100)

            machine_gaps.append(machine_gap)
            compressions.append(compression)

        plt.plot(machine_gaps, compressions, marker='o', linestyle='-')
        plt.xlabel("Machine Gap (inches)")
        plt.ylabel("Compression (%)")
        plt.title(f"Machine Gap vs Compression for Groove Depth {groove_depth} in")
        plt.grid()
        plt.show()
        return []

    for groove_depth in [i * 0.001 for i in range(1, int(ring_thickness * 1000))]:
        for machine_gap in [j * 0.001 for j in range(10, 101)]:  # Machine gap between 0.01 and 0.1 inches
            bulkhead_ID = o_tank_ID - (groove_depth * 2) - machine_gap
            stretch = (bulkhead_ID - ring_ID) / ring_ID
            crossR = 0.5 * stretch
            new_OD = (ring_ID * (1 + stretch)) + (ring_thickness * 2 * (1 - crossR))
            compression = (((ring_thickness * 2 * (1 - crossR)) - (o_tank_ID - bulkhead_ID)) / (
                        ring_thickness * 2 * (1 - crossR)) * 100)

            if compression_range[0] <= compression <= compression_range[1]:
                valid_combinations.append((groove_depth, machine_gap, compression))

    return valid_combinations


# Example usage:
ring_thickness = float(input("Enter O-ring thickness (in inches): "))
ring_ID = float(input("Enter O-ring ID (in inches): "))
ring_OD = float(input("Enter O-ring OD (in inches): "))

groove_depth_input = input("Enter groove depth (or press Enter to auto-calculate valid combinations): ")
groove_depth = float(groove_depth_input) if groove_depth_input else None

# Run calculation
valid_combinations = calculate_o_ring_params(ring_thickness, ring_ID, ring_OD, groove_depth)

if not groove_depth:
    print("Valid Groove Depth and Machine Gap Combinations for Desired Compression:")
    for combo in valid_combinations:
        print(f"Groove Depth: {combo[0]:.4f}, Machine Gap: {combo[1]:.4f}, Compression: {combo[2]:.2f}%")
